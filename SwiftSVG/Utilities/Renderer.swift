//
//  Renderer.swift
//  SwiftSVG
//
//  Created by Jonathan Wight on 8/26/15.
//  Copyright © 2015 No. All rights reserved.
//

import SwiftGraphics

public protocol Renderer: AnyObject {

    func concatTransform(transform:CGAffineTransform)
    func concatCTM(transform:CGAffineTransform)
    func pushGraphicsState()
    func restoreGraphicsState()

    func addPath(path:PathGenerator)
    func addCGPath(path: CGPath)
    func drawPath(mode: CGPathDrawingMode)
    func fillPath()
/*
    func addRect(rect: CGRect)
    func drawLine(startPoint: CGPoint, endPoint: CGPoint)
    func fillCircle(rect: CGRect)
    func strokeCircle(rect: CGRect)
    func fillRect(rect: CGRect)
    func strokeRect(rect: CGRect)
    func fillPolygon(points: [CGPoint])
    func strokePolygon(points: [CGPoint])
*/
    var strokeColor:CGColor? { get set }
    var fillColor:CGColor? { get set }

    var style:Style { get set }

}

// MARK: -

public protocol CustomSourceConvertible {
    func toSource() -> String
}

extension CGAffineTransform: CustomSourceConvertible {
    public func toSource() -> String {
        return "CGAffineTransform(\(a), \(b), \(c), \(d), \(tx), \(ty))"
    }
}


// MARK: -

extension CGContext: Renderer {

    public func concatTransform(transform:CGAffineTransform) {
        CGContextConcatCTM(self, transform)
    }

    public func concatCTM(transform:CGAffineTransform) {
        CGContextConcatCTM(self, transform)
    }

    public func pushGraphicsState() {
        CGContextSaveGState(self)
    }

    public func restoreGraphicsState() {
        CGContextRestoreGState(self)
    }

    public func addCGPath(path: CGPath) {
        CGContextAddPath(self, path)
    }

    public func addPath(path:PathGenerator) {
        addCGPath(path.cgpath)
        CGContextAddPath(self, path.cgpath)
    }

    public func drawPath(mode: CGPathDrawingMode) {
        CGContextDrawPath(self, mode)
    }

    public func fillPath() {
        CGContextFillPath(self)
    }

/*
    public func addRect(rect: CGRect) {
        CGContextAddRect(self, rect)
    }

    public func fillCircle(rect: CGRect) {
        CGContextFillEllipseInRect(self, rect)
    }

    public func strokeCircle(rect: CGRect) {
        CGContextStrokeEllipseInRect(self, rect)
    }

    public func fillRect(rect: CGRect) {
        CGContextFillRect(self, rect)
    }
    
    public func strokeRect(rect: CGRect) {
        CGContextStrokeRect(self, rect)
    }

    public func fillPolygon(points: [CGPoint]) {
        var thePoints = points
        CGContextAddLines(self, &thePoints, thePoints.count)
        CGContextClosePath(self)
        CGContextFillPath(self)
    }
    
    public func strokePolygon(points: [CGPoint]) {
        var thePoints = points
        CGContextAddLines(self, &thePoints, thePoints.count)
        CGContextClosePath(self)
        CGContextStrokePath(self)
    }
    public func drawLine(startPoint: CGPoint, endPoint: CGPoint) {
        CGContextBeginPath(self)
        CGContextMoveToPoint(self, startPoint.x, startPoint.y)
        CGContextAddLineToPoint(self, endPoint.x, endPoint.y)
        CGContextClosePath(self)
        CGContextStrokePath(self)
    }
*/
}

public class MovingImagesRenderer: Renderer {
    public internal(set) var movingImagesJSON = [NSString : AnyObject]()
    
    public func concatTransform(transform:CGAffineTransform) {
        concatCTM(transform)
    }
    
    public func concatCTM(transform:CGAffineTransform) {
        movingImagesJSON[MIJSONKeyAffineTransform] = [
            MIJSONKeyAffineTransformM11 : transform.a,
            MIJSONKeyAffineTransformM12 : transform.b,
            MIJSONKeyAffineTransformM21 : transform.c,
            MIJSONKeyAffineTransformM22 : transform.d,
            MIJSONKeyAffineTransformtX : transform.tx,
            MIJSONKeyAffineTransformtY : transform.ty
        ]
    }

    public func pushGraphicsState() { }
    
    public func restoreGraphicsState() { }
    
    public func addCGPath(path: CGPath) { }
    
    public func addPath(path:PathGenerator) {
        for (key, value) in path.mipath {
            movingImagesJSON[key] = value
        }
        // movingImagesJSON[MIJSONKeyArrayOfPathElements] = miPath[MIJSONKeyArrayOfPathElements]
        // movingImagesJSON[MIJSONKeyStartPoint] = miPath[MIJSONKeyStartPoint]
    }
    
    public func drawPath(mode: CGPathDrawingMode) {
        let miDrawingElement: NSString
        let evenOdd: NSString?
        
        switch(mode) {
        case CGPathDrawingMode.Fill:
            miDrawingElement = MIJSONValuePathFillElement
            evenOdd = "nonwindingrule"
        case CGPathDrawingMode.Stroke:
            miDrawingElement = MIJSONValuePathStrokeElement
            evenOdd = Optional.None
        case CGPathDrawingMode.EOFill:
            miDrawingElement = MIJSONValuePathFillElement
            evenOdd = MIJSONValueEvenOddClippingRule
        case CGPathDrawingMode.EOFillStroke:
            miDrawingElement = MIJSONValuePathFillAndStrokeElement
            evenOdd = MIJSONValueEvenOddClippingRule
        case CGPathDrawingMode.FillStroke:
            miDrawingElement = MIJSONValuePathFillAndStrokeElement
            evenOdd = "nonwindingrule"
        }
        if let rule = evenOdd {
            movingImagesJSON[MIJSONKeyClippingRule] = rule
        }
        movingImagesJSON[MIJSONKeyClippingRule] = miDrawingElement
    }

    public func fillPath() { }

    private func colorDictFromColor(color: CGColor) -> [NSString : AnyObject] {
        var colorDict = [NSString : AnyObject]()
        colorDict[MIJSONKeyColorColorProfileName] = "kCGColorSpaceSRGB"
        let colorComponents = CGColorGetComponents(color)
        colorDict[MIJSONKeyRed] = colorComponents[0]
        colorDict[MIJSONKeyGreen] = colorComponents[1]
        colorDict[MIJSONKeyBlue] = colorComponents[2]
        colorDict[MIJSONKeyAlpha] = colorComponents[3]
        return colorDict
    }

    public var strokeColor:CGColor? {
        get {
            return style.strokeColor
        }
        set {
            style.strokeColor = newValue
            // TODO:
        }
    }
    
    public var fillColor:CGColor? {
        get {
            return style.fillColor
        }
        set {
            style.fillColor = newValue
            // TODO:
        }
    }

    public var style:Style = Style() {
        didSet {
            if let fillColor = style.fillColor {
                self.movingImagesJSON[MIJSONKeyFillColor] = colorDictFromColor(fillColor)
            }
            if let strokeColor = style.strokeColor {
                self.movingImagesJSON[MIJSONKeyStrokeColor] = colorDictFromColor(strokeColor)
            }
            if let lineWidth = style.lineWidth {
                self.movingImagesJSON[MIJSONKeyLineWidth] = lineWidth
            }
            if let lineCap = style.lineCap {
                self.movingImagesJSON[MIJSONKeyLineCap] = lineCap.stringValue
            }
            if let lineJoin = style.lineJoin {
                self.movingImagesJSON[MIJSONKeyLineJoin] = lineJoin.stringValue
            }
            if let miterLimit = style.miterLimit {
                self.movingImagesJSON[MIJSONKeyLineJoin] = miterLimit
            }
            if let alpha = style.alpha {
                self.movingImagesJSON[MIJSONKeyAlpha] = alpha
            }
/*  Not yet implemented in SwiftSVG.
            if let blendMode = newStyle.blendMode {
                setBlendMode(blendMode)
            }
*/
            
// TODO: Not implemented in MovingImages.
/*
            if let lineDash = newStyle.lineDash {
                if let lineDashPhase = newStyle.lineDashPhase {
                    setLineDash(lineDash, phase: lineDashPhase)
                } else {
                    setLineDash(lineDash, phase: 0.0)
                }
            }
            if let flatness = newStyle.flatness {
                setFlatness(flatness)
            }
*/
        }
    }
}

private extension CGLineCap {
    var stringValue: NSString {
        switch(self) {
        case CGLineCap.Butt:
            return "kCGLineCapButt"
        case CGLineCap.Round:
            return "kCGLineCapRound"
        case CGLineCap.Square:
            return "kCGLineCapSquare"
        }
    }
}

private extension CGLineJoin {
    var stringValue: NSString {
        switch(self) {
        case CGLineJoin.Bevel:
            return "kCGLineJoinBevel"
        case CGLineJoin.Miter:
            return "kCGLineJoinMiter"
        case CGLineJoin.Round:
            return "kCGLineJoinRound"
        }
    }
}

// MARK: -

public class SourceCodeRenderer: Renderer {
    public internal(set) var source = ""

    public init() {
        // Shouldn't this be fill color. Default stroke is no stroke.
        // whereas default fill is black. ktam?
        self.style.strokeColor = CGColor.blackColor()
    }

    public func concatTransform(transform:CGAffineTransform) {
        concatCTM(transform)
    }

    public func concatCTM(transform:CGAffineTransform) {
        source += "CGContextConcatCTM(context, \(transform.toSource()))\n"
    }

    public func pushGraphicsState() {
        source += "CGContextSaveGState(context)\n"
    }
    
    public func restoreGraphicsState() {
        source += "CGContextRestoreGState(self)\n"
    }

    public func addCGPath(path: CGPath) {
        source += "CGContextAddPath(context, \(path))\n"
    }

    public func addPath(path:PathGenerator) {
        addCGPath(path.cgpath)
    }

    public func drawPath(mode: CGPathDrawingMode) {
        source += "CGContextDrawPath(context, TODO)\n"
    }

    public func fillPath() {
        source += "CGContextFillPath(context)\n"
    }
/*
    public func addRect(rect:CGRect) {
        source += "CGContextAddRect(context, \(rect))\n"
    }
    
    public func drawLine(startPoint: CGPoint, endPoint: CGPoint) {
        source += "CGContextBeginPath(context)\n" +
                  "CGContextMoveToPoint(context, TODO)\n" +
                  "CGContextAddLineToPoint(context, TODO, TODO)\n" +
                  "CGContextClosePath(context)\n" +
                  "CGContextStrokePath(context)\n"
    }

    public func fillCircle(rect: CGRect) {
        source += "CGContextFillEllipseInRect(context, TODO)\n"
    }
    
    public func strokeCircle(rect: CGRect) {
        source += "CGContextStrokeEllipseInRect(context, TODO)\n"
    }

    public func fillRect(rect: CGRect) {
        source += "CGContextFillRect(context, TODO)\n"
    }
    
    public func strokeRect(rect: CGRect) {
        source += "CGContextStrokeRect(context, TODO)\n"
    }

    public func fillPolygon(points: [CGPoint]) {
        source += "CGContextAddLines(self, TODO)\n" +
                  "CGContextClosePath(self)\n" +
                  "CGContextFillPath(self)\n"
    }
    
    public func strokePolygon(points: [CGPoint]) {
        source += "CGContextAddLines(self, TODO)\n" +
                  "CGContextClosePath(self)\n" +
                  "CGContextStrokePath(self)\n"
    }
*/
    public var strokeColor:CGColor? {
        get {
            return style.strokeColor
        }
        set {
            style.strokeColor = newValue
            source += "CGContextSetStrokeColor(context, TODO)\n"
        }
    }

    public var fillColor:CGColor? {
        get {
            return style.fillColor
        }
        set {
            style.fillColor = newValue
            source += "CGContextSetFillColor(context, TODO)\n"
        }
    }

    public var style:Style = Style() {
        didSet {
            source += "CGContextSetStrokeColor(context, TODO)\n"
            source += "CGContextSetFillColor(context, TODO)\n"
        }
    }
}
