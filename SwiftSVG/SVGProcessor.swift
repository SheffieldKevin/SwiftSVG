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
        if let document = document {
// MARK: MovingImages start.
            document.updateMovingImagesJSON()
// MARK: MovingImages end.
            // document.printElements()
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
// MARK: MovingImages start.
            document.movingImages["viewBox"] = [
                MIJSONKeySize : [ MIJSONKeyWidth : width, MIJSONKeyHeight : height ],
                MIJSONKeyOrigin : [ MIJSONKeyX : x, MIJSONKeyY : y ]
            ]
// MARK: MovingImages end.
        }

        guard let nodes = xmlElement.children else {
            return document
        }

// MARK: MovingImages start.
        // SVG defaults to a black background drawing color.
        let colorDict = try! SVGColors.stringToColorDictionary("black")!
        document.movingImages[MIJSONKeyFillColor] = SVGColors.colorDictToMIColorDict(colorDict)
// MARK: MovingImages end.

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
            case "polygon":
                svgElement = try processSVGPolygon(xmlElement, state:state)
            case "title":
                state.document!.title = xmlElement.stringValue as String?
            case "desc":
                state.document!.documentDescription = xmlElement.stringValue as String?
            default:
                state.events.append(Event(severity: .warning, message: "Unhandled element \(xmlElement.name)"))
                return nil
        }

        if let svgElement = svgElement {
            svgElement.style = try processStyle(xmlElement, state: state, svgElement: svgElement)
            svgElement.transform = try processTransform(xmlElement, state: state)

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
// MARK: MovingImages start.
            if let theTransform = svgElement.transform?.toCGAffineTransform() {
                let transformDict = [
                    MIJSONKeyAffineTransformM11 : theTransform.a,
                    MIJSONKeyAffineTransformM12 : theTransform.b,
                    MIJSONKeyAffineTransformM21 : theTransform.c,
                    MIJSONKeyAffineTransformM22 : theTransform.d,
                    MIJSONKeyAffineTransformtX : theTransform.tx,
                    MIJSONKeyAffineTransformtY : theTransform.ty
                ]
                svgElement.movingImages[MIJSONKeyAffineTransform] = transformDict
            }
            if let id = svgElement.id {
                svgElement.movingImages[MIJSONKeyElementDebugName] = id
            }
// MARK: MovingImages end.
        }
        return svgElement
    }

    public func processSVGGroup(xmlElement: NSXMLElement, state: State) throws -> SVGGroup {
        // A commented out <!--  --> node comes in as a NSXMLNode which causes crashes here.
        let nodes = xmlElement.children!
        var children = [SVGElement]()
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
        let svgElement = SVGPath(path: path)
// MARK: MovingImages start.
        svgElement.movingImages[MIJSONKeyArrayOfPathElements] = pathArray
        svgElement.movingImages[MIJSONKeyStartPoint] = makePointDictionary(CGPoint(x: 0.0, y: 0.0))
// MARK: MovingImages end.
        return svgElement
    }

    private class func stringToCGFloat(string: String?) throws -> CGFloat {
        guard let string = string else {
            throw Error.expectedSVGElementNotFound
        }
        guard let value = NSNumberFormatter().numberFromString(string)?.doubleValue else {
            throw Error.corruptXML
        }
        return CGFloat(value)
    }
    
    private class func stringToCGFloat(string: String?, defaultVal: CGFloat) throws -> CGFloat {
        guard let string = string else {
            return defaultVal
        }

        guard let value = NSNumberFormatter().numberFromString(string)?.doubleValue else {
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

// MARK: MovingImages start.
        svgElement.movingImages[MIJSONKeyStartPoint] = [
            MIJSONKeyX : points[0].x,
            MIJSONKeyY : points[0].y
        ]

        var pathArray = points[1..<points.count].map() {
            return [
                MIJSONKeyElementType : MIJSONValuePathLine,
                MIJSONKeyEndPoint : [ MIJSONKeyX : $0.x, MIJSONKeyY : $0.y ]
            ]
        }
        pathArray.append([MIJSONKeyElementType : MIJSONValueCloseSubPath])
        svgElement.movingImages[MIJSONKeyArrayOfPathElements] = pathArray
// MARK: MovingImages end.
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
// MARK: MovingImages start.
        svgElement.movingImages[MIJSONKeyLine] = makeLineDictionary(startPoint, endPoint: endPoint)
        svgElement.movingImages[MIJSONKeyElementType] = MIJSONValueLineElement
// MARK: MovingImages end.
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
// MARK: MovingImages start.
        svgElement.movingImages[MIJSONKeyRect] = makeRectDictionary(svgElement.rect)
// MARK: MovingImages end.
        return svgElement
    }

    public func processSVGRect(xmlElement: NSXMLElement, state: State) throws -> SVGRect? {
        let x = try SVGProcessor.stringToCGFloat(xmlElement["x"]?.stringValue, defaultVal: 0.0)
        let y = try SVGProcessor.stringToCGFloat(xmlElement["y"]?.stringValue, defaultVal: 0.0)
        let width = try SVGProcessor.stringToCGFloat(xmlElement["width"]?.stringValue)
        let height = try SVGProcessor.stringToCGFloat(xmlElement["height"]?.stringValue)
        
        xmlElement["x"] = nil
        xmlElement["y"] = nil
        xmlElement["width"] = nil
        xmlElement["height"] = nil

        let svgElement = SVGRect(rect: CGRect(x: x, y: y, w: width, h: height))
// MARK: MovingImages start.
        svgElement.movingImages[MIJSONKeyRect] = makeRectDictionary(svgElement.rect)
// MARK: MovingImages end.
        return svgElement
    }
    
    public func processStyle(xmlElement: NSXMLElement,
                                  state: State,
                             svgElement: SVGElement) throws -> SwiftGraphics.Style? {
        var styleElements: [StyleElement] = []

        // http: //www.w3.org/TR/SVG/styling.html

        // If fill is not set then the default fill is black. Fill is not applied
        // if you set fill="none".
        if let value = xmlElement["fill"]?.stringValue {
            if let colorDict = try SVGColors.stringToColorDictionary(value) {
                if let color = SVGColors.colorDictionaryToCGColor(colorDict) {
                    let element = StyleElement.fillColor(color)
                    styleElements.append(element)
                    svgElement.movingImages[MIJSONKeyFillColor] = SVGColors.colorDictToMIColorDict(colorDict)
                }
            }
            else if value == "none" {
                svgElement.drawFill = false
            }
        }
        
        xmlElement["fill"] = nil

        // Stroke
        if let value = xmlElement["stroke"]?.stringValue {
            if let colorDict = try SVGColors.stringToColorDictionary(value) {
                svgElement.movingImages[MIJSONKeyStrokeColor] = colorDict
                if let color = SVGColors.colorDictionaryToCGColor(colorDict) {
                    let element = StyleElement.strokeColor(color)
                    styleElements.append(element)
// MARK: MovingImages start.
                    svgElement.movingImages[MIJSONKeyStrokeColor] = SVGColors.colorDictToMIColorDict(colorDict)
// MARK: MovingImages end.
                }
            }
            xmlElement["stroke"] = nil
        }

        // Stroke-Width
        if let value = xmlElement["stroke-width"]?.stringValue {

            if let double = NSNumberFormatter().numberFromString(value)?.doubleValue {
                let element = StyleElement.lineWidth(CGFloat(double))
                styleElements.append(element)
// MARK: MovingImages start.
                svgElement.movingImages[MIJSONKeyLineWidth] = double
// MARK: MovingImages end.
            }
            xmlElement["stroke-width"] = nil
        }

        // Stroke-Miterlimit
        if let value = xmlElement["stroke-miterlimit"]?.stringValue {
            
            if let double = NSNumberFormatter().numberFromString(value)?.doubleValue {
                let element = StyleElement.miterLimit(CGFloat(double))
                styleElements.append(element)
// MARK: MovingImages start.
                svgElement.movingImages[MIJSONKeyMiter] = double
// MARK: MovingImages end.
            }
            xmlElement["stroke-miterlimit"] = nil
        }

        if let value = xmlElement["display"]?.stringValue {
            if value == "none" {
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

    public func processTransform(xmlElement: NSXMLElement, state: State) throws -> Transform2D? {
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
