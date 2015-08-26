//
//  SVGRenderer.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics

class SVGRenderer {

    struct Callbacks {
        var prerenderElement: ((svgElement:SVGElement, context:CGContext) throws -> Bool)?
        var postrenderElement: ((svgElement:SVGElement, context:CGContext) throws -> Void)?
        var styleForElement: ((svgElement:SVGElement) throws -> Style?)?

        init() {
        }
    }

    var callbacks = Callbacks()

    func prerenderElement(svgElement:SVGElement, context:CGContext) throws -> Bool {
        if let prerenderElement = callbacks.prerenderElement {
            return try prerenderElement(svgElement: svgElement, context: context)
        }
        return true
    }

    func styleForElement(svgElement:SVGElement) throws -> Style? {
        if let style = try callbacks.styleForElement?(svgElement: svgElement) {
            return style
        }
        return svgElement.style
    }

    func renderElement(svgElement:SVGElement, context:CGContext) throws {

        if try prerenderElement(svgElement, context: context) == false {
            return
        }

        if let style = try styleForElement(svgElement) {
            context.style = style
        }

        if let transform = svgElement.transform {
            CGContextConcatCTM(context, transform.asCGAffineTransform())
        }

        switch svgElement {
            case let svgDocument as SVGDocument:
                try renderDocument(svgDocument, context:context)
            case let svgGroup as SVGGroup:
                try renderGroup(svgGroup, context:context)
            case let pathable as CGPathable:
                let path = pathable.cgpath
                let mode = CGPathDrawingMode(strokeColor:context.strokeColor, fillColor:context.fillColor)
                CGContextAddPath(context, path)
                CGContextDrawPath(context, mode)
            default:
                assert(false)
        }
    }

    func pathForElement(svgElement:SVGElement) throws -> CGPath {
        switch svgElement {
            case let svgDocument as SVGDocument:
                let path = CGPathCreateMutable()
                for svgElement in svgDocument.children {
                    CGPathAddPath(path, nil, try pathForElement(svgElement))
                }
                return path
            case let svgGroup as SVGGroup:
                let path = CGPathCreateMutable()
                for svgElement in svgGroup.children {
                    CGPathAddPath(path, nil, try pathForElement(svgElement))
                }
                return path
            case let pathable as CGPathable:
                return pathable.cgpath
            default:
                assert(false)
        }
    }

    func renderDocument(svgDocument:SVGDocument, context:CGContext) throws {
        for child in svgDocument.children {
            try renderElement(child, context:context)
        }
    }

    func renderGroup(svgGroup:SVGGroup, context:CGContext) throws {
        for child in svgGroup.children {
            try renderElement(child, context:context)
        }
    }




}