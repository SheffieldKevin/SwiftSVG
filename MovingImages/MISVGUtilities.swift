//
//  MISVGUtilities.swift
//  SwiftSVG
//
//  Created by Kevin Meaney on 21/09/2015.
//  Copyright © 2015 No. All rights reserved.
//

import Foundation

let defaultSaveFolder = "~/Desktop/Current/swiftsvg"

func jsonObjectToString(jsonObject: AnyObject) -> String? {
    if NSJSONSerialization.isValidJSONObject(jsonObject) {
        let data = try? NSJSONSerialization.dataWithJSONObject(jsonObject,
            options: NSJSONWritingOptions.PrettyPrinted)
        if let data = data,
            let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                return jsonString as String
        }
    }
    return nil
}

public func writeMovingImagesJSONObject(jsonObject: [NSString : AnyObject], fileURL: NSURL) {
    guard let jsonString = jsonObjectToString(jsonObject) else {
        return
    }
    
    do {
        try jsonString.writeToURL(fileURL, atomically: false, encoding: NSUTF8StringEncoding)
    }
    catch {
        print("Failed to save file: \(fileURL.path!)")
    }
}

public func writeMovingImagesJSON(jsonObject: [NSString : AnyObject], sourceFileURL: NSURL) {
    guard let fileName = sourceFileURL.lastPathComponent else {
        return
    }
    
    let shortName = NSString(string: fileName).stringByDeletingPathExtension
    let newName = shortName.stringByAppendingString(".json")
    let saveFolder = NSString(string: defaultSaveFolder).stringByExpandingTildeInPath
    let folderURL = NSURL(fileURLWithPath: saveFolder, isDirectory: true)
    
    guard let newFileURL = NSURL(string: newName, relativeToURL: folderURL) else {
        return
    }
    
    guard let jsonString = jsonObjectToString(jsonObject) else {
        return
    }
    
    do {
        try jsonString.writeToURL(newFileURL, atomically: false, encoding: NSUTF8StringEncoding)
    }
    catch {
        print("Failed to save file: \(saveFolder)/\(newName)")
    }
}

internal func makePointDictionary(point: CGPoint = CGPoint.zero) -> [NSString : AnyObject] {
    return [
        MIJSONKeyX : point.x,
        MIJSONKeyY : point.y
    ]
}

internal func makeLineDictionary(startPoint: CGPoint, endPoint: CGPoint) -> [NSString : AnyObject] {
    return [
        MIJSONKeyLine : [
            MIJSONKeyStartPoint : makePointDictionary(startPoint),
            MIJSONKeyEndPoint : makePointDictionary(endPoint),
        ],
        MIJSONKeyElementType : MIJSONValueLineElement
    ]
}

internal func makePathDictionary(pathElements: NSArray, startPoint: CGPoint = CGPoint.zero) -> [NSString : AnyObject] {
    return [
        MIJSONKeyArrayOfPathElements : pathElements,
        MIJSONKeyStartPoint : makePointDictionary(CGPoint(x: 0.0, y: 0.0))
    ]
}

internal func makeRectDictionary(rectangle: CGRect) -> [NSString : AnyObject] {
    return [
        MIJSONKeySize : [
            MIJSONKeyWidth : rectangle.size.width,
            MIJSONKeyHeight : rectangle.size.height,
        ],
        MIJSONKeyOrigin : [
            MIJSONKeyX : rectangle.origin.x,
            MIJSONKeyY : rectangle.origin.y,
        ]
    ]
}

internal func makeRectDictionary(rectangle: CGRect, makePath: Bool) -> [NSString : AnyObject] {
    if makePath {
        return [
            MIJSONKeyStartPoint : makePointDictionary(),
            MIJSONKeyArrayOfPathElements : [
                [
                    MIJSONKeyElementType : MIJSONValuePathRectangle,
                    MIJSONKeyRect : makeRectDictionary(rectangle)
                ]
            ]
        ]
    }
    else {
        return [
            MIJSONKeyRect : makeRectDictionary(rectangle)
        ]
    }
}

internal func rectElementType(hasFill hasFill: Bool, hasStroke: Bool) -> NSString {
    if hasFill && hasStroke {
        return MIJSONValuePathFillAndStrokeElement
    }
    else if hasFill {
        return MIJSONValueRectangleFillElement
    }
    else if hasStroke {
        return MIJSONValueRectangleStrokeElement
    }
    else {
        return NSString(string: "")
    }
}

internal func makeRectDictionary(rectangle: CGRect, hasFill: Bool, hasStroke: Bool) -> [NSString : AnyObject] {
    var theDict = makeRectDictionary(rectangle, makePath: hasFill && hasStroke)
    theDict[MIJSONKeyElementType] = rectElementType(hasFill: hasFill, hasStroke: hasStroke)
    return theDict
}

internal func pathElementType(hasFill hasFill: Bool, hasStroke: Bool) -> NSString {
    if hasFill && hasStroke {
        return MIJSONValuePathFillAndStrokeElement
    }
    else if hasFill {
        return MIJSONValuePathFillElement
    }
    else if hasStroke {
        return MIJSONValuePathStrokeElement
    }
    else {
        return NSString(string: "")
    }
}

internal func makeRoundedRectDictionary(rectangle: CGRect, rx: CGFloat, ry: CGFloat, hasFill: Bool, hasStroke: Bool) -> [NSString : AnyObject] {
    let x0 = rectangle.origin.x
    let y0 = rectangle.origin.y
    let width = rectangle.size.width
    let height = rectangle.size.height
    
    return [
        MIJSONKeyStartPoint : makePointDictionary(CGPoint(x: x0 + rx, y: y0)),
        MIJSONKeyElementType : pathElementType(hasFill: hasFill, hasStroke: hasStroke),
        MIJSONKeyArrayOfPathElements : [
            [
                MIJSONKeyElementType : MIJSONValuePathLine,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0 + width - rx, y: y0))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathQuadraticCurve,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0 + width, y: y0 + ry)),
                MIJSONKeyControlPoint1 : makePointDictionary(CGPoint(x: x0 + width, y: y0))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathLine,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0 + width, y: y0 + height - ry))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathQuadraticCurve,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0 + width - rx, y: y0 + height)),
                MIJSONKeyControlPoint1 : makePointDictionary(CGPoint(x: x0 + width, y: y0 + height))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathLine,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0 + rx, y: y0 + height))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathQuadraticCurve,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0, y: y0 + height - ry)),
                MIJSONKeyControlPoint1 : makePointDictionary(CGPoint(x: x0, y: y0 + height))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathLine,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0, y: y0 + ry))
            ],
            [
                MIJSONKeyElementType : MIJSONValuePathQuadraticCurve,
                MIJSONKeyEndPoint : makePointDictionary(CGPoint(x: x0 + rx, y: y0)),
                MIJSONKeyControlPoint1 : makePointDictionary(CGPoint(x: x0, y: y0))
            ],
            [
                MIJSONKeyElementType : MIJSONValueCloseSubPath,
            ]
        ]
    ]
}

internal func makeOvalDictionary(rectangle: CGRect, makePath: Bool) -> [NSString : AnyObject] {
    if makePath {
        return [
            MIJSONKeyStartPoint : makePointDictionary(),
            MIJSONKeyArrayOfPathElements : [
                [
                    MIJSONKeyElementType : MIJSONValuePathOval,
                    MIJSONKeyRect : makeRectDictionary(rectangle)
                ]
            ]
        ]
    }
    else {
        return [
            MIJSONKeyRect : makeRectDictionary(rectangle)
        ]
    }
}

internal func makeOvalDictionary(rectangle: CGRect, hasFill: Bool, hasStroke: Bool) -> [NSString : AnyObject] {
    var theDict = makeOvalDictionary(rectangle, makePath: hasFill && hasStroke)
    if hasFill && hasStroke {
        theDict[MIJSONKeyElementType] = MIJSONValuePathFillAndStrokeElement
    }
    else if hasFill {
        theDict[MIJSONKeyElementType] = MIJSONValueOvalFillElement
    }
    else if hasStroke {
        theDict[MIJSONKeyElementType] = MIJSONValueOvalStrokeElement
    }
    return theDict
}

internal func makePolygonArray(points: [CGPoint]) -> [[NSString : AnyObject]] {
    return points.map() {
        return [
            MIJSONKeyElementType : MIJSONValuePathLine,
            MIJSONKeyEndPoint : [ MIJSONKeyX : $0.x, MIJSONKeyY : $0.y ]
        ]
    }
}

internal func makePolygonDictionary(points: [CGPoint]) -> [NSString : AnyObject] {
    var pathArray = makePolygonArray(Array(points[1..<points.count]))
    pathArray.append([MIJSONKeyElementType : MIJSONValueCloseSubPath])
    return [
        MIJSONKeyStartPoint : makePointDictionary(points[0]),
        MIJSONKeyArrayOfPathElements : pathArray
    ]
}

internal func makePolylineDictionary(points: [CGPoint]) -> [NSString : AnyObject] {
    return [
        MIJSONKeyStartPoint : makePointDictionary(points[0]),
        MIJSONKeyArrayOfPathElements : makePolygonArray(Array(points[1..<points.count]))
    ]
}

internal func makeCGAffineTransformDictionary(transform: CGAffineTransform) -> [NSString : AnyObject] {
    return [
        MIJSONKeyAffineTransformM11 : transform.a,
        MIJSONKeyAffineTransformM12 : transform.b,
        MIJSONKeyAffineTransformM21 : transform.c,
        MIJSONKeyAffineTransformM22 : transform.d,
        MIJSONKeyAffineTransformtX : transform.tx,
        MIJSONKeyAffineTransformtY : transform.ty
    ]
}

internal func addMIPaths(inout miPath1: MovingImagesPath, miPath2: MovingImagesPath) {
    if let miPathElements1 = miPath1[MIJSONKeyArrayOfPathElements] as? [[NSString : AnyObject]],
        let miPathElements2 = miPath2[MIJSONKeyArrayOfPathElements] as? [[NSString : AnyObject]]
    {
        miPath1[MIJSONKeyArrayOfPathElements] = miPathElements1 + miPathElements2
    }
}

extension SVGColors {
    class func makeMIColorDictFromColor(color: CGColor) -> [NSString : AnyObject] {
        var colorDict = [NSString : AnyObject]()
        colorDict[MIJSONKeyColorColorProfileName] = "kCGColorSpaceSRGB"
        let colorComponents = CGColorGetComponents(color)
        colorDict[MIJSONKeyRed] = colorComponents[0]
        colorDict[MIJSONKeyGreen] = colorComponents[1]
        colorDict[MIJSONKeyBlue] = colorComponents[2]
        colorDict[MIJSONKeyAlpha] = colorComponents[3]
        return colorDict
    }
}
