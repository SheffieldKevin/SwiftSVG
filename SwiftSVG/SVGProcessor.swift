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
            // document?.optimise()
            document.printElement()
            document.generateMovingImagesJSON()
            if let jsonString = jsonObjectToString(document.movingImages) {
                print(jsonString)
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

        // Children
        if let nodes = xmlElement.children as? [NSXMLElement] {
            for node in nodes {
                if let svgElement = try self.processSVGElement(node, state: state) {
                    svgElement.parent = document
                    document.children.append(svgElement)
                }
            }
            xmlElement.setChildren(nil)
        }
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

            if let id = xmlElement["id"]?.stringValue {
                svgElement.id = id
                if state.elementsByID[id] != nil {
                    state.events.append(Event(severity: .warning, message: "Duplicate elements with id \"\(id)\"."))
                }
                state.elementsByID[id] = svgElement
                xmlElement["id"] = nil
                svgElement.movingImages[MIJSONKeyElementDebugName] = id
            }

            if xmlElement.attributes?.count > 0 {
                state.events.append(Event(severity: .warning, message: "Unhandled attributes: \(xmlElement))"))
                svgElement.xmlElement = xmlElement
            }
        }

        return svgElement
    }

    public func processSVGGroup(xmlElement: NSXMLElement, state: State) throws -> SVGGroup {
        let nodes = xmlElement.children! as! [NSXMLElement]

        let children = try nodes.flatMap() {
            return try processSVGElement($0, state: state)
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
        svgElement.movingImages[MIJSONKeyArrayOfPathElements] = pathArray
        svgElement.movingImages[MIJSONKeyStartPoint] = [
            MIJSONKeyX : 0.0,
            MIJSONKeyY : 0.0
        ]
        return svgElement
    }

    public func processStyle(xmlElement: NSXMLElement,
                                  state: State,
                             svgElement: SVGElement) throws -> SwiftGraphics.Style? {
        var styleElements: [StyleElement] = []

        // http: //www.w3.org/TR/SVG/styling.html

        var hasFill = false
        var hasStroke = false
        
        // Fill
        if let value = xmlElement["fill"]?.stringValue {
            if let colorDict = try stringToColorDictionary(value) {
                if let color = colorDictionaryToCGColor(colorDict) {
                    let element = StyleElement.fillColor(color)
                    styleElements.append(element)
                }
                svgElement.movingImages[MIJSONKeyFillColor] = colorDictToMIColorDict(colorDict)
            }
            hasFill = true
            xmlElement["fill"] = nil
        }

        // Stroke
        if let value = xmlElement["stroke"]?.stringValue {
            if let colorDict = try stringToColorDictionary(value) {
                svgElement.movingImages[MIJSONKeyStrokeColor] = colorDict
                if let color = colorDictionaryToCGColor(colorDict) {
                    let element = StyleElement.strokeColor(color)
                    styleElements.append(element)
                }
                svgElement.movingImages[MIJSONKeyStrokeColor] = colorDictToMIColorDict(colorDict)
            }
            hasStroke = true
            xmlElement["stroke"] = nil
        }

        // Should not be assuming a path for these element types.
        // Either this is a path element, or there is a child path element which
        // would tell us that this is a path element.
        if hasFill {
            if hasStroke {
                svgElement.movingImages[MIJSONKeyElementType] = MIJSONValuePathFillAndStrokeElement
            }
            else
            {
                svgElement.movingImages[MIJSONKeyElementType] = MIJSONValuePathFillElement
            }
        }
        else if hasStroke {
            svgElement.movingImages[MIJSONKeyElementType] = MIJSONValuePathStrokeElement
        }
        
        // Stroke-Width
        if let value = xmlElement["stroke-width"]?.stringValue {

            if let double = NSNumberFormatter().numberFromString(value)?.doubleValue {
                let element = StyleElement.lineWidth(CGFloat(double))
                styleElements.append(element)
                svgElement.movingImages[MIJSONKeyLineWidth] = double
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

    public func processTransform(xmlElement: NSXMLElement, state: State) throws -> Transform2D? {
        guard let value = xmlElement["transform"]?.stringValue else {
            return nil
        }
        let transform = try svgTransformAttributeStringToTransform(value)
        xmlElement["transform"] = nil
        return transform
    }

    func colorDictToMIColorDict(colorDict: [NSObject : AnyObject]) -> [NSObject : AnyObject] {
        let mColorDict = [
            MIJSONKeyRed : colorDict["red"]!,
            MIJSONKeyGreen : colorDict["green"]!,
            MIJSONKeyBlue : colorDict["blue"]!,
            MIJSONKeyColorColorProfileName : kCGColorSpaceSRGB
        ]
        return mColorDict
    }

    func stringToColor(string: String) throws -> CGColor? {
        if string == "none" {
            return nil
        }

        if let colorDictionary = try stringToColorDictionary(string) {
            return colorDictionaryToCGColor(colorDictionary)
        }
        return .None
    }

    func stringToColorDictionary(string: String) throws -> [NSObject : AnyObject]? {
        if string == "none" {
            return nil
        }
        if let colorWithName = SVGStandardColors.colorFromName(string) {
            return try CColorConverter.sharedInstance().colorDictionaryWithString(colorWithName)
        }
        return try CColorConverter.sharedInstance().colorDictionaryWithString(string)
    }

    func colorDictionaryToCGColor(cDict: [NSObject : AnyObject]) -> CGColor? {
        return CGColor.color(red: cDict["red"] as! CGFloat, green: cDict["green"] as! CGFloat,
            blue: cDict["blue"] as! CGFloat, alpha: 1.0)
    }
}

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


