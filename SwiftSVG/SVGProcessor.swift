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

class SVGProcessor {

    class State {
        var document:SVGDocument?
        var elementsByID:[String:SVGElement] = [:]
        var events:[Event] = []
    }


    func processXMLDocument(xmlDocument:NSXMLDocument) throws -> SVGDocument? {
        let rootElement = xmlDocument.rootElement()!
        let state = State()
        let document = try self.processSVGElement(rootElement, state:state) as? SVGDocument
        if state.events.count > 0 {
            for event in state.events {
                print(event)
            }
        }

        return document
    }

    func processSVGDocument(xmlElement:NSXMLElement, state:State) throws -> SVGDocument {
        let document = SVGDocument()
        state.document = document

        // Version.
        if let version = xmlElement["version"]?.stringValue {
            switch version {
                case "1.1":
                    document.profile = .full
                    document.version = SVGDocument.Version(majorVersion:1, minorVersion:1)
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
            let values:[CGFloat] = (try! VALUE_LIST.parse(viewbox).value as? [Any])!.map() {
                return $0 as! CGFloat
            }

            let (x, y, width, height) = (values[0], values[1], values[2], values[3])
            document.viewBox = CGRect(x:x, y:y, width:width, height:height)

            xmlElement["viewBox"] = nil
        }

        // Children
        if let nodes = xmlElement.children as? [NSXMLElement] {
            for node in nodes {
                if let svgElement = try self.processSVGElement(node, state:state) {
                    svgElement.parent = document
                    document.children.append(svgElement)
                }
            }
            xmlElement.setChildren(nil)
        }

        return document
    }

    func processSVGElement(xmlElement:NSXMLElement, state:State) throws -> SVGElement? {

        var svgElement:SVGElement? = nil

        switch xmlElement.name! {
            case "svg":
                svgElement = try processSVGDocument(xmlElement, state:state)
            case "g":
                svgElement = try processSVGGroup(xmlElement, state:state)
            case "path":
                svgElement = try processSVGPath(xmlElement, state:state)
            case "title":
                state.document!.title = xmlElement.stringValue as String?
            case "desc":
                state.document!.documentDescription = xmlElement.stringValue as String?
            default:
                state.events.append(Event(severity: .warning, message: "Unhandled element \(xmlElement.name)"))
                return nil
        }

        if let svgElement = svgElement {
            svgElement.style = try processStyle(xmlElement, state:state)
            svgElement.transform = try processTransform(xmlElement, state:state)

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

    func processSVGGroup(xmlElement:NSXMLElement, state:State) throws -> SVGGroup {
        let group = SVGGroup()
        let nodes = xmlElement.children! as! [NSXMLElement]
        for node in nodes {
            if let svgElement = try self.processSVGElement(node, state:state) {
                svgElement.parent = group
                group.children.append(svgElement)
            }
        }
        xmlElement.setChildren(nil)
        return group
    }

    func processSVGPath(xmlElement:NSXMLElement, state:State) throws -> SVGPath? {
        let dAttribute = xmlElement["d"]
        // TODO - can crash!
        let path = CGPathFromSVGPath(dAttribute!.stringValue!)
        xmlElement["d"] = nil
        return SVGPath(path:path)
    }

    func processStyle(xmlElement:NSXMLElement, state:State) throws -> SwiftGraphics.Style? {
        let style = try processSVGStyle(xmlElement, state: state)
        return style
    }

    func processTransform(xmlElement:NSXMLElement, state:State) throws -> Transform2D? {
        guard let value = xmlElement["transform"]?.stringValue else {
            return nil
        }
        let transform = try svgTransformAttributeStringToTransform(value)
        xmlElement["transform"] = nil
        return transform
    }
}

