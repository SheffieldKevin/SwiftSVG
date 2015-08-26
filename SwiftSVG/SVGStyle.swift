//
//  SVGStyle.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 3/22/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation
import SwiftGraphics

func stringToColor(string:String) throws -> CGColor? {

    let colorDictionary = try? CColorConverter.sharedInstance().colorDictionaryWithString(string)
    if let colorDictionary = colorDictionary {
        let color = CGColor.color(red: colorDictionary["red"] as! CGFloat , green: colorDictionary["green"] as! CGFloat, blue: colorDictionary["blue"] as! CGFloat, alpha: 1.0)
        return color
    }
    else {
        return nil
    }

}


func processSVGStyle(xmlElement:NSXMLElement, state:SVGProcessor.State) throws -> SwiftGraphics.Style? {

    var styleElements:[StyleElement] = []

// http://www.w3.org/TR/SVG/styling.html

    // Fill
    if let value = xmlElement["fill"]?.stringValue {
        if let color = try stringToColor(value) {
            let element = StyleElement.fillColor(color)
            styleElements.append(element)
        }

        xmlElement["fill"] = nil
    }

    // Stroke
    if let value = xmlElement["stroke"]?.stringValue {
        if let color = try stringToColor(value) {
            let element = StyleElement.strokeColor(color)
            styleElements.append(element)
        }

        xmlElement["stroke"] = nil
    }

    // Stroke-Width
    if let value = xmlElement["stroke-width"]?.stringValue {

        if let double = NSNumberFormatter().numberFromString(value)?.doubleValue {
            let element = StyleElement.lineWidth(CGFloat(double))
            styleElements.append(element)
        }

        xmlElement["stroke-width"] = nil
    }


    //
    if styleElements.count > 0 {
        return SwiftGraphics.Style(elements: styleElements)
    }
    else {
        return nil
    }
}
