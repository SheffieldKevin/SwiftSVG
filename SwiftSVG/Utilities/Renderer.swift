//
//  Renderer.swift
//  SwiftSVG
//
//  Created by Jonathan Wight on 8/26/15.
//  Copyright © 2015 No. All rights reserved.
//

import SwiftGraphics

public protocol Renderer: AnyObject {

    func concatTransform(transform:CGAffineTransform)
    func concatCTM(transform:CGAffineTransform)
    func pushGraphicsState()
    func restoreGraphicsState()

    func startDocument(viewBox: CGRect)
    func startGroup(id: String?)
    func endElement()
    func startElement(id: String?)
    
    func addPath(path:CGPathable)
    func addCGPath(path: CGPath)
    func drawPath(mode: CGPathDrawingMode)
    func drawText(textRenderer: TextRenderer)
    func fillPath()
    
    func render() -> String

    var strokeColor:CGColor? { get set }
    var fillColor:CGColor? { get set }
    var lineWidth:CGFloat? { get set }

    var style:Style { get set }

}

// MARK: -

public protocol CustomSourceConvertible {
    func toSource() -> String
}

extension CGAffineTransform: CustomSourceConvertible {
    public func toSource() -> String {
        return "CGAffineTransform(\(a), \(b), \(c), \(d), \(tx), \(ty))"
    }
}

// MARK: - CGContext renderer

extension CGContext: Renderer {

    public func concatTransform(transform:CGAffineTransform) {
        CGContextConcatCTM(self, transform)
    }

    public func concatCTM(transform:CGAffineTransform) {
        CGContextConcatCTM(self, transform)
    }

    public func pushGraphicsState() {
        CGContextSaveGState(self)
    }

    public func restoreGraphicsState() {
        CGContextRestoreGState(self)
    }

    public func startDocument(viewBox: CGRect) { }
    
    public func startGroup(id: String?) { }

    public func endElement() { }
    
    public func startElement(id: String?) { }

    public func addCGPath(path: CGPath) {
        CGContextAddPath(self, path)
    }

    public func addPath(path:CGPathable) {
        addCGPath(path.cgpath)
    }

    public func drawPath(mode: CGPathDrawingMode) {
        CGContextDrawPath(self, mode)
    }
    
    public func drawText(textRenderer: TextRenderer) {
        self.pushGraphicsState()
        CGContextTranslateCTM(self, 0.0, textRenderer.textOrigin.y)
        CGContextScaleCTM(self, 1.0, -1.0)
        let line = CTLineCreateWithAttributedString(textRenderer.cttext)
        CGContextSetTextPosition(self, textRenderer.textOrigin.x, 0.0)
        CTLineDraw(line, self)
        self.restoreGraphicsState()
    }
    
    public func fillPath() {
        CGContextFillPath(self)
    }
    
    public func render() -> String { return "" }
}

// MARK: -

public class SourceCodeRenderer: Renderer {
    public internal(set) var source = ""

    public init() {
        // Shouldn't this be fill color. Default stroke is no stroke.
        // whereas default fill is black. ktam?
        self.style.strokeColor = CGColor.blackColor()
    }

    public func concatTransform(transform:CGAffineTransform) {
        concatCTM(transform)
    }

    public func concatCTM(transform:CGAffineTransform) {
        source += "CGContextConcatCTM(context, \(transform.toSource()))\n"
    }

    public func pushGraphicsState() {
        source += "CGContextSaveGState(context)\n"
    }
    
    public func restoreGraphicsState() {
        source += "CGContextRestoreGState(self)\n"
    }

    public func startGroup(id: String?) { }
    
    public func endElement() { }
    
    public func startElement(id: String?) { }

    public func startDocument(viewBox: CGRect) { }
    
    public func addCGPath(path: CGPath) {
        source += "CGContextAddPath(context, \(path))\n"
    }

    public func addPath(path:CGPathable) {
        addCGPath(path.cgpath)
    }

    public func drawPath(mode: CGPathDrawingMode) {
        source += "CGContextDrawPath(context, TODO)\n"
    }

    public func drawText(textRenderer: TextRenderer) {
        
    }
    
    public func fillPath() {
        source += "CGContextFillPath(context)\n"
    }

    public func render() -> String {
        return source
    }

    public var strokeColor:CGColor? {
        get {
            return style.strokeColor
        }
        set {
            style.strokeColor = newValue
            source += "CGContextSetStrokeColor(context, TODO)\n"
        }
    }

    public var fillColor:CGColor? {
        get {
            return style.fillColor
        }
        set {
            style.fillColor = newValue
            source += "CGContextSetFillColor(context, TODO)\n"
        }
    }

    public var lineWidth:CGFloat? {
        get {
            return style.lineWidth
        }
        set {
            style.lineWidth = newValue
            source += "CGContextSetLineWidth(context, TODO)\n"
        }
    }

    public var style:Style = Style() {
        didSet {
            source += "CGContextSetStrokeColor(context, TODO)\n"
            source += "CGContextSetFillColor(context, TODO)\n"
        }
    }
}
