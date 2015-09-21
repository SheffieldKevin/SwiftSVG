//
//  SVGRenderer.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics

public class SVGRenderer {

    public struct Callbacks {
        public var prerenderElement: ((svgElement: SVGElement, renderer: Renderer) throws -> Bool)? = nil
        public var postrenderElement: ((svgElement: SVGElement, renderer: Renderer) throws -> Void)? = nil
        public var styleForElement: ((svgElement: SVGElement) throws -> Style?)? = nil
    }

    public var callbacks = Callbacks()

    public init() {
    }

    public func prerenderElement(svgElement: SVGElement, renderer: Renderer) throws -> Bool {
        if let prerenderElement = callbacks.prerenderElement {
            return try prerenderElement(svgElement: svgElement, renderer: renderer)
        }
        return true
    }

    public func styleForElement(svgElement: SVGElement) throws -> Style? {
        if let style = try callbacks.styleForElement?(svgElement: svgElement) {
            return style
        }
        return svgElement.style
    }

    public func renderElement(svgElement: SVGElement, renderer: Renderer) throws {

        if try prerenderElement(svgElement, renderer: renderer) == false {
            return
        }

        if let style = try styleForElement(svgElement) {
            renderer.style = style
        }

        if let transform = svgElement.transform {
            renderer.concatTransform(transform.toCGAffineTransform())
            // TODO: Why are not cleanign this up at end of function?
        }

        switch svgElement {
            case let svgDocument as SVGDocument:
                try renderDocument(svgDocument, renderer: renderer)
            case let svgGroup as SVGGroup:
                try renderGroup(svgGroup, renderer: renderer)
            case let svgLine as SVGLine:
                renderer.drawLine(svgLine.startPoint, endPoint: svgLine.endPoint)
            case let pathable as CGPathable:
                let path = pathable.cgpath
                let mode = CGPathDrawingMode(strokeColor: renderer.strokeColor, fillColor: renderer.fillColor)
                renderer.addPath(path)
                renderer.drawPath(mode)
            default:
                assert(false)
        }
    }

    public func pathForElement(svgElement: SVGElement) throws -> CGPath {
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

    public func renderDocument(svgDocument: SVGDocument, renderer: Renderer) throws {
        for child in svgDocument.children {
            try renderElement(child, renderer: renderer)
        }
    }

    public func renderGroup(svgGroup: SVGGroup, renderer: Renderer) throws {
        for child in svgGroup.children {
            try renderElement(child, renderer: renderer)
        }
    }




}