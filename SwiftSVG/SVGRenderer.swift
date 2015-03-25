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
        var prerenderElement: ((svgElement:SVGElement, context:CGContext) -> Bool)?
        var postrenderElement: ((svgElement:SVGElement, context:CGContext) -> Void)?
        var styleForElement: ((svgElement:SVGElement) -> Style?)?

        init() {
        }
    }

    var callbacks = Callbacks()

    func prerenderElement(svgElement:SVGElement, context:CGContext) -> Bool {
        if let prerenderElement = callbacks.prerenderElement {
            return prerenderElement(svgElement: svgElement, context: context)
        }
        return true
    }

    func styleForElement(svgElement:SVGElement) -> Style? {
        if let style = callbacks.styleForElement?(svgElement: svgElement) {
            return style
        }
        return svgElement.style
    }

    func renderElement(svgElement:SVGElement, context:CGContext) {

        if prerenderElement(svgElement, context: context) == false {
            return
        }

        if let style = styleForElement(svgElement) {
            context.style = style
        }

        if let transform = svgElement.transform {
            CGContextConcatCTM(context, transform.asCGAffineTransform())
        }

        switch svgElement {
            case let svgDocument as SVGDocument:
                renderDocument(svgDocument, context:context)
            case let svgGroup as SVGGroup:
                renderGroup(svgGroup, context:context)
            case let pathable as CGPathable:
                let path = pathable.cgpath
                let mode = CGPathDrawingMode(strokeColor:context.strokeColor, fillColor:context.fillColor)
                CGContextAddPath(context, path)
                CGContextDrawPath(context, mode)
            default:
                assert(false)
        }
    }

    func pathForElement(svgElement:SVGElement) -> CGPath {
        switch svgElement {
            case let svgDocument as SVGDocument:
                var path = CGPathCreateMutable()
                for svgElement in svgDocument.children {
                    CGPathAddPath(path, nil, pathForElement(svgElement))
                }
                return path
            case let svgGroup as SVGGroup:
                var path = CGPathCreateMutable()
                for svgElement in svgGroup.children {
                    CGPathAddPath(path, nil, pathForElement(svgElement))
                }
                return path
            case let pathable as CGPathable:
                return pathable.cgpath
            default:
                assert(false)
        }
    }

    func renderDocument(svgDocument:SVGDocument, context:CGContext) {
        for child in svgDocument.children {
            renderElement(child, context:context)
        }
    }

    func renderGroup(svgGroup:SVGGroup, context:CGContext) {
        for child in svgGroup.children {
            renderElement(child, context:context)
        }
    }




}