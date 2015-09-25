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
            //            options: NSJSONWritingOptions(rawValue: 0))
        if let data = data,
            let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                return jsonString as String
        }
    }
    return nil
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
        MIJSONKeyStartPoint : makePointDictionary(startPoint),
        MIJSONKeyEndPoint : makePointDictionary(endPoint)
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

private func updateStrokeOrFillType(svgElement: SVGElement,
    strokeElementKey: NSString, fillElementKey: NSString) {
    let hasStroke = !(svgElement.strokeColor == nil)
    let hasFill = !(svgElement.fillColor == nil)
    
    if hasStroke {
        if hasFill {
            var element1 = svgElement.movingImages
            element1[MIJSONKeyElementType] = fillElementKey
            var element2 = svgElement.movingImages
            element2[MIJSONKeyElementType] = strokeElementKey
            svgElement.movingImages = [
                MIJSONKeyElementType : MIJSONValueArrayOfElements,
                MIJSONValueArrayOfElements : [ element1, element2 ]
            ]
        }
        else {
            svgElement.movingImages[MIJSONKeyElementType] = strokeElementKey
        }
    }
    else if hasFill {
        svgElement.movingImages[MIJSONKeyElementType] = fillElementKey
    }
}

func updateMovingImagesElementType(svgElement: SVGElement) {
    if svgElement.movingImages[MIJSONKeyElementType] == nil {
        switch svgElement {
        case let svgCircle as SVGCircle:
            updateStrokeOrFillType(svgCircle, strokeElementKey: MIJSONValueOvalStrokeElement, fillElementKey: MIJSONValueOvalFillElement)
        case let svgPolygon as SVGPolygon:
            svgPolygon.movingImages[MIJSONKeyElementType] = svgPolygon.getPathElementType()
        case let svgPolyline as SVGPolyline:
            svgPolyline.movingImages[MIJSONKeyElementType] = svgPolyline.getPathElementType()
        case let svgRect as SVGRect:
            updateStrokeOrFillType(svgRect, strokeElementKey: MIJSONValueRectangleStrokeElement, fillElementKey: MIJSONValueRectangleFillElement)
        case let svgEllipse as SVGEllipse:
            updateStrokeOrFillType(svgEllipse, strokeElementKey: MIJSONValueOvalStrokeElement, fillElementKey: MIJSONValueOvalFillElement)
        case let path as SVGPath:
            path.movingImages[MIJSONKeyElementType] = path.getPathElementType()
        default:
            return
        }
    }
}
