//
//  MIPathFromSwiftSVGPath.swift
//  SwiftSVG
//
//  Created by Kevin Meaney on 17/09/2015.
//  Copyright © 2015 No. All rights reserved.
//

import Foundation

/*
public func MICGPathFromSVGPath(d:String) -> CGMutablePath
{
    let path = CGPathCreateMutable()
    var callBacks = kCFTypeArrayCallBacks
    let pathArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, &callBacks)
    
    MI_CGPathFromSVGPath(path, pathArray, d)
    
    if NSJSONSerialization.isValidJSONObject(pathArray) {
        let data = try? NSJSONSerialization.dataWithJSONObject(pathArray,
            options: NSJSONWritingOptions.PrettyPrinted)
        if let data = data,
            let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                print(jsonString)
        }
    }

    return path
}
*/

public func MICGPathFromSVGPath(d:String, inout pathArray: NSMutableArray) -> CGMutablePath
{

    let path = CGPathCreateMutable()
/*
    var callBacks = kCFTypeArrayCallBacks
    let pathArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, &callBacks)
*/
    //    let pathArray = NSMutableArray(capacity: 0)
    MI_CGPathFromSVGPath(path, pathArray, d)
    //    drawElement[MIJSONKeyArrayOfPathElements] = pathArray;
/*
    if NSJSONSerialization.isValidJSONObject(pathArray) {
        let data = try? NSJSONSerialization.dataWithJSONObject(pathArray,
            options: NSJSONWritingOptions.PrettyPrinted)
        if let data = data,
            let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                print(jsonString)
        }
    }
*/
    return path
}
