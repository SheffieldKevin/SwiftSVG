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

public func makePointDictionary(point: CGPoint) -> [NSString : AnyObject] {
    return [
        MIJSONKeyX : point.x,
        MIJSONKeyY : point.y
    ]
}

public func makeLineDictionary(startPoint: CGPoint, endPoint: CGPoint) -> [NSString : AnyObject] {
    return [
        MIJSONKeyStartPoint : makePointDictionary(startPoint),
        MIJSONKeyEndPoint : makePointDictionary(endPoint)
    ]
}

public func makeRectDictionary(rectangle: CGRect) -> [NSString : AnyObject] {
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
