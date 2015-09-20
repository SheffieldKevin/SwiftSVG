//
//  MIPathFromSVGPath.m lifted from CGPathFromSVGPath.m
//  SwiftGraphics
//
//  Created by Zhang Yungui on 2/11/15.
//  Copyright (c) 2015 schwa.io. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "MIPathFromSVGPath.h"
#import "MIJSONConstants.h"

#include <tgmath.h>
#include <string.h>
#include <stdlib.h>

/*
static CFStringRef kElementType = CFSTR("elementtype");
static CFStringRef kPoint = CFSTR("point");
static CFStringRef kX = CFSTR("x");
static CFStringRef kY = CFSTR("y");
static CFStringRef kSize = CFSTR("size");
static CFStringRef kWidth = CFSTR("width");
static CFStringRef kHeight = CFSTR("height");
*/

static bool mi_svg_isspace(char c) {
    return strchr(" \t\n\v\f\r", c) != 0;
}

static bool mi_svg_isdigit(char c) {
    return strchr("0123456789", c) != 0;
}

static bool mi_svg_isnum(char c) {
    return strchr("0123456789+-.eE", c) != 0;
}

static const char* mi_svg_getNextPathItem(const char* s, char* it)
{
    int i = 0;
    it[0] = '\0';
    // Skip white spaces and commas
    while (*s && (mi_svg_isspace(*s) || *s == ',')) s++;
    if (!*s) return s;
    if (*s == '-' || *s == '+' || mi_svg_isdigit(*s)) {
        // sign
        if (*s == '-' || *s == '+') {
            if (i < 63) it[i++] = *s;
            s++;
        }
        // integer part
        while (*s && mi_svg_isdigit(*s)) {
            if (i < 63) it[i++] = *s;
            s++;
        }
        if (*s == '.') {
            // decimal point
            if (i < 63) it[i++] = *s;
            s++;
            // fraction part
            while (*s && mi_svg_isdigit(*s)) {
                if (i < 63) it[i++] = *s;
                s++;
            }
        }
        // exponent
        if (*s == 'e' || *s == 'E') {
            if (i < 63) it[i++] = *s;
            s++;
            if (*s == '-' || *s == '+') {
                if (i < 63) it[i++] = *s;
                s++;
            }
            while (*s && mi_svg_isdigit(*s)) {
                if (i < 63) it[i++] = *s;
                s++;
            }
        }
        it[i] = '\0';
    } else {
        // Parse command
        it[0] = *s++;
        it[1] = '\0';
        return s;
    }
    
    return s;
}

static int mi_svg_getArgsPerElement(char cmd)
{
    switch (cmd) {
        case 'v':
        case 'V':
        case 'h':
        case 'H':
            return 1;
        case 'm':
        case 'M':
        case 'l':
        case 'L':
        case 't':
        case 'T':
            return 2;
        case 'q':
        case 'Q':
        case 's':
        case 'S':
            return 4;
        case 'c':
        case 'C':
            return 6;
        case 'a':
        case 'A':
            return 7;
    }
    return 0;
}

static CGFloat mi_svg_sqr(CGFloat x) { return x*x; }
static CGFloat mi_svg_vmag(CGFloat x, CGFloat y) { return sqrt(x*x + y*y); }

static CGFloat mi_svg_vecrat(CGFloat ux, CGFloat uy, CGFloat vx, CGFloat vy)
{
    return (ux*vx + uy*vy) / (mi_svg_vmag(ux,uy) * mi_svg_vmag(vx,vy));
}

static CGFloat mi_svg_vecang(CGFloat ux, CGFloat uy, CGFloat vx, CGFloat vy)
{
    CGFloat r = mi_svg_vecrat(ux,uy, vx,vy);
    if (r < -1.0f) r = -1.0f;
    if (r > 1.0f) r = 1.0f;
    return ((ux*vy < uy*vx) ? -1.0f : 1.0f) * acos(r);
}

static void mi_svg_xformPoint(CGFloat* dx, CGFloat* dy, CGFloat x, CGFloat y, const CGFloat* t)
{
    *dx = x*t[0] + y*t[2] + t[4];
    *dy = x*t[1] + y*t[3] + t[5];
}

static void mi_svg_xformVec(CGFloat* dx, CGFloat* dy, CGFloat x, CGFloat y, const CGFloat* t)
{
    *dx = x*t[0] + y*t[2];
    *dy = x*t[1] + y*t[3];
}

NSDictionary *MI_CreateCurveDictionary(CGFloat cp1x, CGFloat cp1y, CGFloat cp2x,
                                       CGFloat cp2y, CGFloat x, CGFloat y);

static void mi_svg_pathArcTo(NSMutableArray *pathArray, CGMutablePathRef path, const CGFloat* args, bool rel)
{
    // Ported from canvg (https://code.google.com/p/canvg/)
    CGFloat rx, ry, rotx;
    CGFloat x1, y1, x2, y2, cx, cy, dx, dy, d;
    CGFloat x1p, y1p, cxp, cyp, s, sa, sb;
    CGFloat ux, uy, vx, vy, a1, da;
    CGFloat x, y, tanx, tany, a, px=0, py=0, ptanx=0, ptany=0, t[6];
    CGFloat sinrx, cosrx;
    int fa, fs;
    int i, ndivs;
    CGFloat hda, kappa;
    CGPoint end = CGPathGetCurrentPoint(path);
    
    rx = fabs(args[0]);				// y radius
    ry = fabs(args[1]);				// x radius
    rotx = args[2] * M_PI / 180.f;      // x rotation engle
    fa = fabs(args[3]) > 1e-6 ? 1 : 0;	// Large arc
    fs = fabs(args[4]) > 1e-6 ? 1 : 0;	// Sweep direction
    x1 = end.x;                          // start point
    y1 = end.y;
    if (rel) {							// end point
        x2 = end.x + args[5];
        y2 = end.y + args[6];
    } else {
        x2 = args[5];
        y2 = args[6];
    }
    
    dx = x1 - x2;
    dy = y1 - y2;
    d = sqrt(dx*dx + dy*dy);
    if (d < 1e-6f || rx < 1e-6f || ry < 1e-6f) {
        // The arc degenerates to a line
        CGPathAddLineToPoint(path, nil, x2, y2);
        return;
    }
    
    sinrx = sin(rotx);
    cosrx = cos(rotx);
    
    // Convert to center point parameterization.
    // http://www.w3.org/TR/SVG11/implnote.html#ArcImplementationNotes
    // 1) Compute x1', y1'
    x1p = cosrx * dx / 2.0f + sinrx * dy / 2.0f;
    y1p = -sinrx * dx / 2.0f + cosrx * dy / 2.0f;
    d = mi_svg_sqr(x1p)/mi_svg_sqr(rx) + mi_svg_sqr(y1p)/mi_svg_sqr(ry);
    if (d > 1) {
        d = sqrt(d);
        rx *= d;
        ry *= d;
    }
    // 2) Compute cx', cy'
    s = 0.0f;
    sa = mi_svg_sqr(rx)*mi_svg_sqr(ry) - mi_svg_sqr(rx)*mi_svg_sqr(y1p) - mi_svg_sqr(ry)*mi_svg_sqr(x1p);
    sb = mi_svg_sqr(rx)*mi_svg_sqr(y1p) + mi_svg_sqr(ry)*mi_svg_sqr(x1p);
    if (sa < 0.0f) sa = 0.0f;
    if (sb > 0.0f)
        s = sqrt(sa / sb);
    if (fa == fs)
        s = -s;
    cxp = s * rx * y1p / ry;
    cyp = s * -ry * x1p / rx;
    
    // 3) Compute cx,cy from cx',cy'
    cx = (x1 + x2)/2.0f + cosrx*cxp - sinrx*cyp;
    cy = (y1 + y2)/2.0f + sinrx*cxp + cosrx*cyp;
    
    // 4) Calculate theta1, and delta theta.
    ux = (x1p - cxp) / rx;
    uy = (y1p - cyp) / ry;
    vx = (-x1p - cxp) / rx;
    vy = (-y1p - cyp) / ry;
    a1 = mi_svg_vecang(1.0f,0.0f, ux,uy);	// Initial angle
    da = mi_svg_vecang(ux,uy, vx,vy);		// Delta angle
    
    //if (vecrat(ux,uy,vx,vy) <= -1.0f) da = M_PI;
    //if (vecrat(ux,uy,vx,vy) >= 1.0f) da = 0;
    
    if (fa) {
        // Choose large arc
        if (da > 0.0f)
            da = da - M_PI * 2;
        else
            da = M_PI * 2 + da;
    }
    
    // Approximate the arc using cubic spline segments.
    t[0] = cosrx; t[1] = sinrx;
    t[2] = -sinrx; t[3] = cosrx;
    t[4] = cx; t[5] = cy;
    
    // Split arc into max 90 degree segments.
    ndivs = (int)(fabs(da) / M_PI_2 + 0.5f);
    hda = (da / (CGFloat)ndivs) / 2.0f;
    kappa = fabs(4.0f / 3.0f * (1.0f - cos(hda)) / sin(hda));
    if (da < 0.0f)
        kappa = -kappa;

    NSDictionary *elementDict;
    for (i = 0; i <= ndivs; i++) {
        a = a1 + da * (i/(CGFloat)ndivs);
        dx = cos(a);
        dy = sin(a);
        mi_svg_xformPoint(&x, &y, dx*rx, dy*ry, t); // position
        mi_svg_xformVec(&tanx, &tany, -dy*rx * kappa, dx*ry * kappa, t); // tangent
        if (i > 0) {
            if (rel) {
                CGPathAddCurveToPoint(path, nil, px+ptanx+end.x, py+ptany+end.y,
                                      x-tanx+end.x, y-tany+end.y, x+end.x, y+end.y);
                elementDict = MI_CreateCurveDictionary(px+ptanx+end.x, py+ptany+end.y,
                                                       x-tanx+end.x, y-tany+end.y,
                                                       x+end.x, y+end.y);
                [pathArray addObject:elementDict];

            } else {
                CGPathAddCurveToPoint(path, nil, px+ptanx, py+ptany, x-tanx, y-tany, x, y);
                elementDict = MI_CreateCurveDictionary(px+ptanx, py+ptany,
                                                       x-tanx, y-tany, x, y);
                [pathArray addObject:elementDict];
            }
        }
        px = x;
        py = y;
        ptanx = tanx;
        ptany = tany;
    }
}

static void mi_svg_pathApplier(void *info, const CGPathElement *element)
{
    CGPoint* pts = (CGPoint*)info;
    int n = 0;
    
    switch (element->type) {
        case kCGPathElementMoveToPoint:
            pts[0] = element->points[0];
            pts[1] = pts[0];
            n = 1;
            break;
        case kCGPathElementAddLineToPoint:
            pts[1] = pts[0];                // last point
            pts[0] = element->points[0];
            n = 1;
            break;
        case kCGPathElementAddQuadCurveToPoint:
            n = 2;
            break;
        case kCGPathElementAddCurveToPoint:
            n = 3;
            break;
        default:
            break;
    }
    if (n > 1) {
        for (int i = 0; i < n; ++i) {       // pts[0]: end point
            pts[i] = element->points[n - i - 1];
        }
    }
}

static CGPoint mi_svg_outControlPoint(CGMutablePathRef path)
{
    CGPoint pts[3] = { CGPointZero, CGPointZero, CGPointZero };
    CGPathApply(path, pts, mi_svg_pathApplier);
    return CGPointMake(2 * pts[0].x - pts[1].x, 2 * pts[0].y - pts[1].y);
}

/*
 NSString *const MIJSONKeyElementType = @"elementtype";
 NSString *const MIJSONValuePathMoveTo = @"pathmoveto"; // { point }
 NSString *const MIJSONValuePathLine = @"pathlineto"; // { endpoint }
 NSString *const MIJSONValuePathBezierCurve = @"pathbeziercurve";
 NSString *const MIJSONValuePathQuadraticCurve = @"pathquadraticcurve";
 NSString *const MIJSONValuePathRectangle = @"pathrectangle"; // { rect }
 NSString *const MIJSONValuePathRoundedRectangle = @"pathroundedrectangle";
 NSString *const MIJSONValuePathOval = @"pathoval"; // { rect }
 NSString *const MIJSONValuePathArc = @"patharc";
 NSString *const MIJSONValuePathAddArcToPoint = @"pathaddarctopoint";
 NSString *const MIJSONValueCloseSubPath = @"pathclosesubpath"; // nil
 NSString *const MIJSONKeyControlPoint1 = @"controlpoint1"; // { x, y }
 NSString *const MIJSONKeyControlPoint2 = @"controlpoint2"; // { x, y }
*/

NSDictionary *MI_CreateCloseSubpathDictionary()
{
    return @{ MIJSONKeyElementType : MIJSONValueCloseSubPath };
}

NSDictionary *MI_CreateMovetoDictionary(CGFloat x, CGFloat y)
{
    return @{ MIJSONKeyElementType : MIJSONValuePathMoveTo,
              MIJSONKeyPoint : @{ MIJSONKeyX : @(x), MIJSONKeyY : @(y) } };
}

NSDictionary *MI_CreateLinetoDictionary(CGFloat x, CGFloat y)
{
    return @{ MIJSONKeyElementType : MIJSONValuePathLine,
              MIJSONKeyEndPoint : @{ MIJSONKeyX : @(x), MIJSONKeyY : @(y) } };
}

NSDictionary *MI_CreateCurveDictionary(CGFloat cp1x, CGFloat cp1y, CGFloat cp2x,
                                       CGFloat cp2y, CGFloat x, CGFloat y)
{
    return @{ MIJSONKeyElementType : MIJSONValuePathBezierCurve,
              MIJSONKeyControlPoint1 : @{ MIJSONKeyX : @(cp1x), MIJSONKeyY : @(cp1y) },
              MIJSONKeyControlPoint2 : @{ MIJSONKeyX : @(cp2x), MIJSONKeyY : @(cp2y) },
              MIJSONKeyEndPoint : @{ MIJSONKeyX : @(x), MIJSONKeyY : @(y) } };
}

NSDictionary *MI_CreateQuadCurveDictionary(CGFloat cp1x, CGFloat cp1y,
                                           CGFloat x, CGFloat y)
{
    return @{ MIJSONKeyElementType : MIJSONValuePathQuadraticCurve,
              MIJSONKeyControlPoint1 : @{ MIJSONKeyX : @(cp1x), MIJSONKeyY : @(cp1y) },
              MIJSONKeyEndPoint : @{ MIJSONKeyX : @(x), MIJSONKeyY : @(y) } };
}

// Convert path string as the ‘d’ attribute of SVG path to CGPath.
// The path string, as the ‘d’ attribute of SVG path, begins with a ‘M’ character and can contain
// instructions as described in http://www.w3.org/TR/SVGTiny12/paths.html

void MI_CGPathFromSVGPath(CGMutablePathRef path, NSMutableArray *pathArray,
                          const char* s)
{
    char item[64];
    char cmd = 0;
    CGFloat args[10] = { 0, 0, 0, 0, 0, 0 };
    int nargs = 0;
    int rargs = 0;
    CGPoint end;
    BOOL hasCurrent = NO;
    NSDictionary *elementDict;

    while (*s) {
        s = mi_svg_getNextPathItem(s, item);
        if (!*item) break;
        if (!mi_svg_isnum(item[0])) {
            cmd = item[0];
            rargs = mi_svg_getArgsPerElement(cmd);
            nargs = 0;
            if (cmd == 'Z' || cmd == 'z') {
                CGPathCloseSubpath(path);
                [pathArray addObject:MI_CreateCloseSubpathDictionary()];
            }
        } else {
            if (nargs < 10)
                args[nargs++] = atof(item);
            if (nargs >= rargs) {
                switch (cmd) {
                    case 'm':
                    case 'M':
                        if (cmd == 'm' && hasCurrent == YES) {
                            end = CGPathGetCurrentPoint(path);
                            CGPathMoveToPoint(path, nil, args[0]+end.x, args[1]+end.y);
                            elementDict = MI_CreateMovetoDictionary(args[0] + end.x,
                                                                    args[1]+end.y);
                            [pathArray addObject:elementDict];
                        } else {
                            CGPathMoveToPoint(path, nil, args[0], args[1]);
                            elementDict = MI_CreateMovetoDictionary(args[0], args[1]);
                            [pathArray addObject:elementDict];
                            hasCurrent = YES;
                        }
                        // Moveto can be followed by multiple coordinate pairs,
                        // which should be treated as linetos.
                        cmd = (cmd == 'm') ? 'l' : 'L';
                        rargs = mi_svg_getArgsPerElement(cmd);
                        break;
                    case 'l':
                    case 'L':
                        if (cmd == 'l') {
                            end = CGPathGetCurrentPoint(path);
                            CGPathAddLineToPoint(path, nil, args[0]+end.x, args[1]+end.y);
                            elementDict = MI_CreateLinetoDictionary(args[0]+end.x,
                                                                    args[1]+end.y);
                            [pathArray addObject:elementDict];
                        } else {
                            CGPathAddLineToPoint(path, nil, args[0], args[1]);
                            elementDict = MI_CreateLinetoDictionary(args[0], args[1]);
                            [pathArray addObject:elementDict];
                        }
                        break;
                    case 'H':
                    case 'h':
                        end = CGPathGetCurrentPoint(path);
                        CGFloat x = cmd == 'h' ? args[0] + end.x : args[0];
                        CGPathAddLineToPoint(path, nil, x, end.y);
                        elementDict = MI_CreateLinetoDictionary(x, end.y);
                        [pathArray addObject:elementDict];
                        break;
                    case 'V':
                    case 'v':
                        end = CGPathGetCurrentPoint(path);
                        CGPathAddLineToPoint(path, nil, end.x, cmd == 'v' ? args[0] + end.y : args[0]);
                        CGFloat y = cmd == 'v' ? args[0] + end.y : args[0];
                        elementDict = MI_CreateLinetoDictionary(end.x, y);
                        [pathArray addObject:elementDict];
                        break;
                    case 'C':
                    case 'c':
                        if (cmd == 'c') {
                            end = CGPathGetCurrentPoint(path);
                            CGPathAddCurveToPoint(path, nil, args[0]+end.x, args[1]+end.y,
                                                  args[2]+end.x, args[3]+end.y, args[4]+end.x, args[5]+end.y);
                            elementDict = MI_CreateCurveDictionary(args[0]+end.x,
                                                                   args[1]+end.y,
                                                                   args[2]+end.x,
                                                                   args[3]+end.y,
                                                                   args[4]+end.x,
                                                                   args[5]+end.y);
                            [pathArray addObject:elementDict];
                        } else {
                            CGPathAddCurveToPoint(path, nil, args[0], args[1], args[2], args[3], args[4], args[5]);
                            elementDict = MI_CreateCurveDictionary(args[0],
                                                                   args[1],
                                                                   args[2],
                                                                   args[3],
                                                                   args[4],
                                                                   args[5]);
                            [pathArray addObject:elementDict];
                        }
                        break;
                    case 'S':
                    case 's': {
                        CGPoint cp1 = mi_svg_outControlPoint(path);
                        if (cmd == 's') {
                            end = CGPathGetCurrentPoint(path);
                            CGPathAddCurveToPoint(path, nil, cp1.x, cp1.y, args[0]+end.x, args[1]+end.y,
                                                  args[2]+end.x, args[3]+end.y);
                            elementDict = MI_CreateCurveDictionary(cp1.x,
                                                                   cp1.y,
                                                                   args[0]+end.x,
                                                                   args[1]+end.y,
                                                                   args[2]+end.x,
                                                                   args[3]+end.y);
                            [pathArray addObject:elementDict];

                        } else {
                            CGPathAddCurveToPoint(path, nil, cp1.x, cp1.y, args[0], args[1], args[2], args[3]);
                            elementDict = MI_CreateCurveDictionary(cp1.x,
                                                                   cp1.y,
                                                                   args[0],
                                                                   args[1],
                                                                   args[2],
                                                                   args[3]);
                            [pathArray addObject:elementDict];
                        }
                        break;
                    }
                    case 'Q':
                    case 'q':
                        if (cmd == 'q') {
                            end = CGPathGetCurrentPoint(path);
                            CGPathAddQuadCurveToPoint(path, nil, args[0]+end.x, args[1]+end.y,
                                                      args[2]+end.x, args[3]+end.y);
                            elementDict = MI_CreateQuadCurveDictionary(args[0]+end.x,
                                                                       args[1]+end.y,
                                                                       args[2]+end.x,
                                                                       args[3]+end.y);
                            [pathArray addObject:elementDict];
                        } else {
                            CGPathAddQuadCurveToPoint(path, nil, args[0], args[1], args[2], args[3]);
                            elementDict = MI_CreateQuadCurveDictionary(args[0],
                                                                       args[1],
                                                                       args[2],
                                                                       args[3]);
                            [pathArray addObject:elementDict];
                        }
                        break;
                    case 'T':
                    case 't': {
                        CGPoint cp1 = mi_svg_outControlPoint(path);
                        if (cmd == 't') {
                            end = CGPathGetCurrentPoint(path);
                            CGPathAddQuadCurveToPoint(path, nil, cp1.x, cp1.y, args[0]+end.x, args[1]+end.y);
                            elementDict = MI_CreateQuadCurveDictionary(cp1.x,
                                                                       cp1.y,
                                                                       args[0]+end.x,
                                                                       args[1]+end.x);
                            [pathArray addObject:elementDict];
                        } else {
                            CGPathAddQuadCurveToPoint(path, nil, cp1.x, cp1.y, args[0], args[1]);
                            elementDict = MI_CreateQuadCurveDictionary(cp1.x,
                                                                       cp1.y,
                                                                       args[0],
                                                                       args[1]);
                            [pathArray addObject:elementDict];
                        }
                        break;
                    }
                    case 'A':
                    case 'a':
                        mi_svg_pathArcTo(pathArray, path, args, cmd == 'a' ? 1 : 0);
                        break;
                    default:
                        break;
                }
                nargs = 0;
            }
        }
    }
}

/*
CGMutablePathRef MICGPathFromSVGPath(const char *s)
{
    CGMutablePathRef path = CGPathCreateMutable();
    MI_CGPathFromSVGPath(path, s);
    return path;
}
*/
