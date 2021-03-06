//
//  SVGProcessor.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics
import SwiftParsing

public class SVGProcessor {

    public class State {
        var document: SVGDocument?
        var elementsByID: [String: SVGElement] = [: ]
        var events: [Event] = []
    }

    public struct Event {
        enum Severity {
            case debug
            case info
            case warning
            case error
        }

        let severity: Severity
        let message: String
    }

    public enum Error: ErrorType {
        case corruptXML
        case expectedSVGElementNotFound
    }

    public init() {
    }

    public func processXMLDocument(xmlDocument: NSXMLDocument) throws -> SVGDocument? {
        let rootElement = xmlDocument.rootElement()!
        let state = State()
        let document = try self.processSVGElement(rootElement, state: state) as? SVGDocument
        if state.events.count > 0 {
            for event in state.events {
                print(event)
            }
        }
        return document
    }

    public func processSVGDocument(xmlElement: NSXMLElement, state: State) throws -> SVGDocument {
        let document = SVGDocument()
        state.document = document

        // Version.
        if let version = xmlElement["version"]?.stringValue {
            switch version {
                case "1.1":
                    document.profile = .full
                    document.version = SVGDocument.Version(majorVersion: 1, minorVersion: 1)
                default:
                    break
            }
            xmlElement["version"] = nil
        }

        // Viewbox.
        if let viewbox = xmlElement["viewBox"]?.stringValue {
            let OPT_COMMA = zeroOrOne(COMMA).makeStripped()
            let VALUE_LIST = RangeOf(min: 4, max: 4, subelement: (cgFloatValue + OPT_COMMA).makeStripped().makeFlattened())

            // TODO: ! can and will crash with bad data.
            let values: [CGFloat] = (try! VALUE_LIST.parse(viewbox).value as? [Any])!.map() {
                return $0 as! CGFloat
            }

            let (x, y, width, height) = (values[0], values[1], values[2], values[3])
            document.viewBox = CGRect(x: x, y: y, width: width, height: height)

            xmlElement["viewBox"] = nil
        }
        else if let _ = xmlElement["width"]?.stringValue, let _ = xmlElement["height"]?.stringValue {
            let width = try SVGProcessor.stringToCGFloat(xmlElement["width"]?.stringValue)
            let height = try SVGProcessor.stringToCGFloat(xmlElement["height"]?.stringValue)
            let x = try SVGProcessor.stringToCGFloat(xmlElement["x"]?.stringValue, defaultVal: 0.0)
            let y = try SVGProcessor.stringToCGFloat(xmlElement["y"]?.stringValue, defaultVal: 0.0)
            document.viewBox = CGRect(x: x, y: y, width: width, height: height)
        }

        xmlElement["width"] = nil
        xmlElement["height"] = nil
        xmlElement["x"] = nil
        xmlElement["y"] = nil
        
        guard let nodes = xmlElement.children else {
            return document
        }

        for node in nodes where node is NSXMLElement {
            if let svgElement = try self.processSVGElement(node as! NSXMLElement, state: state) {
                svgElement.parent = document
                document.children.append(svgElement)
            }
        }
        xmlElement.setChildren(nil)
        return document
    }

    public func processSVGElement(xmlElement: NSXMLElement, state: State) throws -> SVGElement? {

        var svgElement: SVGElement? = nil

        guard let name = xmlElement.name else {
            throw Error.corruptXML
        }

        switch name {
            //            case "defs":
            //    svgElement = try processDEFS(xmlElement, state: state)
            case "svg":
                svgElement = try processSVGDocument(xmlElement, state: state)
            case "g":
                svgElement = try processSVGGroup(xmlElement, state: state)
            case "path":
                svgElement = try processSVGPath(xmlElement, state: state)
            case "line":
                svgElement = try processSVGLine(xmlElement, state: state)
            case "circle":
                svgElement = try processSVGCircle(xmlElement, state: state)
            case "rect":
                svgElement = try processSVGRect(xmlElement, state: state)
            case "ellipse":
                svgElement = try processSVGEllipse(xmlElement, state: state)
            case "polygon":
                svgElement = try processSVGPolygon(xmlElement, state:state)
            case "polyline":
                svgElement = try processSVGPolyline(xmlElement, state:state)
            case "text":
                svgElement = try processSVGText(xmlElement)
            case "title":
                state.document!.title = xmlElement.stringValue as String?
            case "desc":
                state.document!.documentDescription = xmlElement.stringValue as String?
            default:
                state.events.append(Event(severity: .warning, message: "Unhandled element \(xmlElement.name)"))
                return nil
        }

        if let svgElement = svgElement {
            svgElement.textStyle = try processTextStyle(xmlElement)
            svgElement.style = try processStyle(xmlElement, svgElement: svgElement)
            svgElement.transform = try processTransform(xmlElement)

            if let id = xmlElement["id"]?.stringValue {
                svgElement.id = id
                if state.elementsByID[id] != nil {
                    state.events.append(Event(severity: .warning, message: "Duplicate elements with id \"\(id)\"."))
                }
                state.elementsByID[id] = svgElement
                xmlElement["id"] = nil
            }

            if xmlElement.attributes?.count > 0 {
                state.events.append(Event(severity: .warning, message: "Unhandled attributes: \(xmlElement))"))
                svgElement.xmlElement = xmlElement
            }
        }
        return svgElement
    }

    public func processDEFS(xmlElement: NSXMLElement, state: State) throws -> SVGElement? {
        // A def element can be children of documents and groups.
        // Any member of def elements should be accessible anywhere within the SVGDocument.
        guard let nodes = xmlElement.children else {
            throw Error.corruptXML
        }
        
        // I suspect that we might need a seperate processor for members of the defs element.
        var defElements = [SVGElement]()
        for node in nodes where node is NSXMLElement {
            if let svgElement = try self.processSVGElement(node as! NSXMLElement, state: state) {
                defElements.append(svgElement)
            }
        }
        return nil
    }

    public func processSVGGroup(xmlElement: NSXMLElement, state: State) throws -> SVGGroup? {
        guard let nodes = xmlElement.children else {
            return .None
        }
        var children = [SVGElement]()
        // A commented out <!--  --> node comes in as a NSXMLNode which causes crashes here.
        for node in nodes where node is NSXMLElement {
            if let svgElement = try self.processSVGElement(node as! NSXMLElement, state: state) {
                children.append(svgElement)
            }
        }

        let group = SVGGroup(children: children)
        xmlElement.setChildren(nil)
        return group
    }

    public func processSVGPath(xmlElement: NSXMLElement, state: State) throws -> SVGPath? {
        guard let string = xmlElement["d"]?.stringValue else {
            throw Error.expectedSVGElementNotFound
        }

        var pathArray = NSMutableArray(capacity: 0)
        let path = MICGPathFromSVGPath(string, pathArray: &pathArray)
        xmlElement["d"] = nil
        let svgElement = SVGPath(path: path, miPath: makePathDictionary(pathArray))
        return svgElement
    }

    private class func stringToCGFloat(string: String?) throws -> CGFloat {
        guard let string = string else {
            throw Error.expectedSVGElementNotFound
        }
        // This is probably a bit reckless. 
        let string2 = string.stringByTrimmingCharactersInSet(NSCharacterSet.lowercaseLetterCharacterSet())
        guard let value = NSNumberFormatter().numberFromString(string2)?.doubleValue else {
            throw Error.corruptXML
        }
        return CGFloat(value)
    }
    
    private class func stringToOptionalCGFloat(string: String?) throws -> CGFloat? {
        guard let string = string else {
            return Optional.None
        }
        let string2 = string.stringByTrimmingCharactersInSet(NSCharacterSet.lowercaseLetterCharacterSet())
        guard let value = NSNumberFormatter().numberFromString(string2)?.doubleValue else {
            throw Error.corruptXML
        }
        return CGFloat(value)
    }
    
    private class func stringToCGFloat(string: String?, defaultVal: CGFloat) throws -> CGFloat {
        guard let string = string else {
            return defaultVal
        }

        let string2 = string.stringByTrimmingCharactersInSet(NSCharacterSet.lowercaseLetterCharacterSet())
        guard let value = NSNumberFormatter().numberFromString(string2)?.doubleValue else {
            throw Error.corruptXML
        }
        return CGFloat(value)
    }
    
    public func processSVGPolygon(xmlElement: NSXMLElement, state: State) throws -> SVGPolygon? {
        guard let pointsString = xmlElement["points"]?.stringValue else {
            throw Error.expectedSVGElementNotFound
        }
        let points = try parseListOfPoints(pointsString)
        
        xmlElement["points"] = nil
        let svgElement = SVGPolygon(points: points)
        return svgElement
    }

    public func processSVGPolyline(xmlElement: NSXMLElement, state: State) throws -> SVGPolyline? {
        guard let pointsString = xmlElement["points"]?.stringValue else {
            throw Error.expectedSVGElementNotFound
        }
        let points = try parseListOfPoints(pointsString)
        
        xmlElement["points"] = nil
        let svgElement = SVGPolyline(points: points)
        return svgElement
    }

    public func processSVGLine(xmlElement: NSXMLElement, state: State) throws -> SVGLine? {
        let x1 = try SVGProcessor.stringToCGFloat(xmlElement["x1"]?.stringValue)
        let y1 = try SVGProcessor.stringToCGFloat(xmlElement["y1"]?.stringValue)
        let x2 = try SVGProcessor.stringToCGFloat(xmlElement["x2"]?.stringValue)
        let y2 = try SVGProcessor.stringToCGFloat(xmlElement["y2"]?.stringValue)

        xmlElement["x1"] = nil
        xmlElement["y1"] = nil
        xmlElement["x2"] = nil
        xmlElement["y2"] = nil
        
        let startPoint = CGPoint(x: x1, y: y1)
        let endPoint = CGPoint(x: x2, y: y2)
        
        let svgElement = SVGLine(startPoint: startPoint, endPoint: endPoint)
        return svgElement
    }

    public func processSVGCircle(xmlElement: NSXMLElement, state: State) throws -> SVGCircle? {
        let cx = try SVGProcessor.stringToCGFloat(xmlElement["cx"]?.stringValue)
        let cy = try SVGProcessor.stringToCGFloat(xmlElement["cy"]?.stringValue)
        let r = try SVGProcessor.stringToCGFloat(xmlElement["r"]?.stringValue)

        xmlElement["cx"] = nil
        xmlElement["cy"] = nil
        xmlElement["r"] = nil
        
        let svgElement = SVGCircle(center: CGPoint(x: cx, y: cy), radius: r)
        return svgElement
    }

    public func processSVGEllipse(xmlElement: NSXMLElement, state: State) throws -> SVGEllipse? {
        let cx = try SVGProcessor.stringToCGFloat(xmlElement["cx"]?.stringValue, defaultVal: 0.0)
        let cy = try SVGProcessor.stringToCGFloat(xmlElement["cy"]?.stringValue, defaultVal: 0.0)
        let rx = try SVGProcessor.stringToCGFloat(xmlElement["rx"]?.stringValue)
        let ry = try SVGProcessor.stringToCGFloat(xmlElement["ry"]?.stringValue)
        
        xmlElement["cx"] = nil
        xmlElement["cy"] = nil
        xmlElement["rx"] = nil
        xmlElement["ry"] = nil

        let rect = CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry)
        let svgElement = SVGEllipse(rect: rect)
        return svgElement
    }
    
    public func processSVGRect(xmlElement: NSXMLElement, state: State) throws -> SVGRect? {
        let x = try SVGProcessor.stringToCGFloat(xmlElement["x"]?.stringValue, defaultVal: 0.0)
        let y = try SVGProcessor.stringToCGFloat(xmlElement["y"]?.stringValue, defaultVal: 0.0)
        let width = try SVGProcessor.stringToCGFloat(xmlElement["width"]?.stringValue)
        let height = try SVGProcessor.stringToCGFloat(xmlElement["height"]?.stringValue)
        let rx = try SVGProcessor.stringToOptionalCGFloat(xmlElement["rx"]?.stringValue)
        let ry = try SVGProcessor.stringToOptionalCGFloat(xmlElement["ry"]?.stringValue)
        
        xmlElement["x"] = nil
        xmlElement["y"] = nil
        xmlElement["width"] = nil
        xmlElement["height"] = nil
        xmlElement["rx"] = nil
        xmlElement["ry"] = nil

        let svgElement = SVGRect(rect: CGRect(x: x, y: y, w: width, h: height), rx: rx, ry: ry)
        return svgElement
    }

    private func getAttributeWithKey(xmlElement: NSXMLElement, attribute: String) -> String? {
        if let name = xmlElement[attribute]?.stringValue {
            return name
        }
        
        // lets see if the font family name is in the style attribute.
        guard let style = xmlElement["style"]?.stringValue else {
            return Optional.None
        }
        
        let seperators = NSCharacterSet(charactersInString: ";")
        let trimChars = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        let parts = style.componentsSeparatedByCharactersInSet(seperators)
        let pairSeperator = NSCharacterSet(charactersInString: ":")
        
        for part in parts {
            let pair = part.componentsSeparatedByCharactersInSet(pairSeperator)
            if pair.count != 2 {
                continue
            }
            let propertyName = pair[0].stringByTrimmingCharactersInSet(trimChars)
            let value = pair[1].stringByTrimmingCharactersInSet(trimChars)
            if propertyName == attribute {
                return value
            }
        }
        return Optional.None
    }
    
    func processSVGTextSpan(xmlElement: NSXMLElement, textOrigin: CGPoint) throws -> SVGTextSpan? {
        let x = try SVGProcessor.stringToCGFloat(xmlElement["x"]?.stringValue, defaultVal: textOrigin.x)
        let y = try SVGProcessor.stringToCGFloat(xmlElement["y"]?.stringValue, defaultVal: textOrigin.y)
        let newOrigin = CGPoint(x: x, y: y)
        guard let string = xmlElement.stringValue else {
            throw Error.corruptXML
        }
        let textSpan = SVGTextSpan(string: string, textOrigin: newOrigin)
        let textStyle = try self.processTextStyle(xmlElement)
        let style = try processStyle(xmlElement)
        let transform = try processTransform(xmlElement)
        textSpan.textStyle = textStyle
        textSpan.style = style
        textSpan.transform = transform
        return textSpan
    }
    
    public func processSVGText(xmlElement: NSXMLElement) throws -> SVGSimpleText? {
        // Since I am not tracking the size of drawn text we can't do any text flow.
        // This means any text that isn't explicitly positioned we can't render.
        
        let x = try SVGProcessor.stringToCGFloat(xmlElement["x"]?.stringValue, defaultVal: 0.0)
        let y = try SVGProcessor.stringToCGFloat(xmlElement["y"]?.stringValue, defaultVal: 0.0)
        let textOrigin = CGPoint(x: x, y: y)

        xmlElement["x"] = nil
        xmlElement["y"] = nil

        guard let nodes = xmlElement.children where nodes.count > 0 else {
            throw Error.expectedSVGElementNotFound
        }
        
        let textSpans = try nodes.map { node -> SVGTextSpan? in
            if let textItem = node as? NSXMLElement {
                return try self.processSVGTextSpan(textItem, textOrigin: textOrigin)
            }
            else if let string = node.stringValue {
                return SVGTextSpan(string: string, textOrigin: textOrigin)
            }
            return nil
        }

        let flattenedTextSpans = textSpans.flatMap { $0 }
        
        xmlElement.setChildren(nil)
        if flattenedTextSpans.count > 0 {
            return SVGSimpleText(spans: flattenedTextSpans)
        }
        return nil
    }
    
    private class func processColorString(colorString: String) -> [NSObject : AnyObject]? {
        // Double optional. What?
        let colorDict = try? SVGColors.stringToColorDictionary(colorString)
        if let colorDict = colorDict {
            return colorDict
        }
        return nil
    }
    
    private class func processFillColor(colorString: String, svgElement: SVGElement? = nil) -> StyleElement? {
        if let svgElement = svgElement where colorString == "none" {
            svgElement.drawFill = false
            return nil
        }
        if let colorDict = processColorString(colorString),
            let color = SVGColors.colorDictionaryToCGColor(colorDict)
        {
            return StyleElement.fillColor(color)
        }
        else {
            return nil
        }
    }

    private class func processStrokeColor(colorString: String) -> StyleElement? {
        if let colorDict = processColorString(colorString),
            let color = SVGColors.colorDictionaryToCGColor(colorDict)
        {
            return StyleElement.strokeColor(color)
        }
        else {
            return nil
        }
    }
    
    private class func processPresentationAttribute(style: String, inout styleElements: [StyleElement], svgElement: SVGElement? = nil) throws {
        let seperators = NSCharacterSet(charactersInString: ";")
        let trimChars = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        let parts = style.componentsSeparatedByCharactersInSet(seperators)
        let pairSeperator = NSCharacterSet(charactersInString: ":")
                                                
        let styles:[StyleElement?] = parts.map {
            let pair = $0.componentsSeparatedByCharactersInSet(pairSeperator)
            if pair.count != 2 {
                return nil
            }
            let propertyName = pair[0].stringByTrimmingCharactersInSet(trimChars)
            let value = pair[1].stringByTrimmingCharactersInSet(trimChars)
            switch(propertyName) {
                case "fill":
                    return processFillColor(value, svgElement: svgElement)
                case "stroke":
                    return processStrokeColor(value)
                case "stroke-width":
                    let floatVal = try? SVGProcessor.stringToCGFloat(value)
                    if let strokeValue = floatVal {
                        return StyleElement.lineWidth(strokeValue)
                    }
                    return nil
                case "stroke-miterlimit":
                    let floatVal = try? SVGProcessor.stringToCGFloat(value)
                    if let miterLimit = floatVal {
                        return StyleElement.miterLimit(miterLimit)
                    }
                    return nil
                case "display":
                    if let svgElement = svgElement where value == "none" {
                        svgElement.display = false
                    }
                    return nil
                default:
                    return nil
            }
        }
        
        styles.forEach {
            if let theStyle = $0 {
                styleElements.append(theStyle)
            }
        }
    }
    
    public func processTextStyle(xmlElement: NSXMLElement) throws -> TextStyle? {
        // We won't be scrubbing the style element after checking for font family and font size here.
        var textStyleElements: [TextStyleElement] = []
        let fontFamily = self.getAttributeWithKey(xmlElement, attribute: "font-family")
        if let fontFamily = fontFamily {
            let familyName = fontFamily.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "'"))
            textStyleElements.append(TextStyleElement.fontFamily(familyName))
        }
        xmlElement["font-family"] = nil
        
        let fontSizeString = self.getAttributeWithKey(xmlElement, attribute: "font-size")
        if let fontSizeString = fontSizeString {
            let fontSize = try SVGProcessor.stringToCGFloat(fontSizeString)
            textStyleElements.append(TextStyleElement.fontSize(fontSize))
        }
        xmlElement["font-size"] = nil
        if textStyleElements.count > 0 {
            var textStyle = TextStyle()
            textStyleElements.forEach {
                textStyle.add($0)
            }
            return textStyle
        }
        return nil
    }
    
    public func processStyle(xmlElement: NSXMLElement, svgElement: SVGElement? = nil) throws -> SwiftGraphics.Style? {
        // http://www.w3.org/TR/SVG/styling.html
        var styleElements: [StyleElement] = []

        if let value = xmlElement["style"]?.stringValue {
            try SVGProcessor.processPresentationAttribute(value, styleElements: &styleElements, svgElement: svgElement)
            xmlElement["style"] = nil
        }

        if let value = xmlElement["fill"]?.stringValue {
            if let styleElement = SVGProcessor.processFillColor(value, svgElement: svgElement) {
                styleElements.append(styleElement)
            }
            xmlElement["fill"] = nil
        }
        
        if let value = xmlElement["stroke"]?.stringValue {
            if let styleElement = SVGProcessor.processStrokeColor(value) {
                styleElements.append(styleElement)
            }
            xmlElement["stroke"] = nil
        }

        let stroke = try SVGProcessor.stringToOptionalCGFloat(xmlElement["stroke-width"]?.stringValue)
        if let strokeValue = stroke {
            styleElements.append(StyleElement.lineWidth(strokeValue))
        }
        xmlElement["stroke-width"] = nil

        let mitreLimit = try SVGProcessor.stringToOptionalCGFloat(xmlElement["stroke-miterlimit"]?.stringValue)
        if let mitreLimitValue = mitreLimit {
            styleElements.append(StyleElement.miterLimit(mitreLimitValue))
        }
        xmlElement["stroke-miterlimit"] = nil

        if let value = xmlElement["display"]?.stringValue {
            if let svgElement = svgElement where value == "none" {
                svgElement.display = false
            }
            xmlElement["display"] = nil
        }
                            
        //
        if styleElements.count > 0 {
            return SwiftGraphics.Style(elements: styleElements)
        }
        else {
            return nil
        }
    }

    public func processTransform(xmlElement: NSXMLElement) throws -> Transform2D? {
        guard let value = xmlElement["transform"]?.stringValue else {
            return nil
        }
        let transform = try svgTransformAttributeStringToTransform(value)
        xmlElement["transform"] = nil
        return transform
    }

    // TODO: @schwa - I couldn't work out how to apply your parser to an array of points float,float
    /// Convert an even list of floats to CGPoints
    private func floatsToPoints(data: [Float]) throws -> [CGPoint] {
        guard data.count % 2 == 0 else {
            throw Error.corruptXML
        }
        var out : [CGPoint] = []
        for var i = 0; i < data.count-1; i += 2 {
            out.append(CGPointMake(CGFloat(data[i]), CGFloat(data[i+1])))
        }
        return out
    }

    /// Parse the list of points from a polygon/polyline entry
    private func parseListOfPoints(entry : String) throws -> [CGPoint] {
        // Split by all commas and whitespace, then group into coords of two floats
        let entry = entry.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        let separating = NSMutableCharacterSet.whitespaceAndNewlineCharacterSet()
        separating.addCharactersInString(",")
        let parts = entry.componentsSeparatedByCharactersInSet(separating).filter { !$0.isEmpty }
        return try floatsToPoints(parts.map({Float($0)!}))
    }
}

// MARK: -

extension SVGProcessor.Event: CustomStringConvertible {
    public var description: String {
        get {
            switch severity {
                case .debug:
                    return "DEBUG: \(message)"
                case .info:
                    return "INFO: \(message)"
                case .warning:
                    return "WARNING: \(message)"
                case .error:
                    return "ERROR: \(message)"
            }
        }
    }
}
