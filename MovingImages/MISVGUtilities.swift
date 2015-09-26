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

internal func makeRectDictionary(rectangle: CGRect, hasFill: Bool, hasStroke: Bool) -> [NSString : AnyObject] {
    var theDict = makeRectDictionary(rectangle, makePath: hasFill && hasStroke)
    if hasFill && hasStroke {
        theDict[MIJSONKeyElementType] = MIJSONValuePathFillAndStrokeElement
    }
    else if hasFill {
        theDict[MIJSONKeyElementType] = MIJSONValueRectangleFillElement
    }
    else if hasStroke {
        theDict[MIJSONKeyElementType] = MIJSONValueRectangleStrokeElement
    }
    return theDict
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
