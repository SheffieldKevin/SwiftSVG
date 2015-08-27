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

    func addPath(path:CGPath)
    func fillPath()
    func drawPath(mode: CGPathDrawingMode)

    var strokeColor:CGColor? { get set }
    var fillColor:CGColor? { get set }

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


// MARK: -

extension CGContext: Renderer {

    public func concatTransform(transform:CGAffineTransform) {
        CGContextConcatCTM(self, transform)
    }

    public func concatCTM(transform:CGAffineTransform) {
        CGContextConcatCTM(self, transform)
    }

    public func addPath(path:CGPath) {
        CGContextAddPath(self, path)
    }

    public func fillPath() {
        CGContextFillPath(self)
    }


    public func drawPath(mode: CGPathDrawingMode) {
        CGContextDrawPath(self, mode)
    }


}

// MARK: -



public class SourceCodeRenderer: Renderer {
    public internal(set) var source = ""

    public init() {
        self.style.strokeColor = CGColor.blackColor()
    }

    public func concatTransform(transform:CGAffineTransform) {
        concatCTM(transform)
    }

    public func concatCTM(transform:CGAffineTransform) {
        source += "CGContextConcatCTM(context, \(transform.toSource()))\n"
    }

    public func addPath(path:CGPath) {
        source += "CGContextAddPath(context, \(path))\n"
    }

    public func fillPath() {
        source += "CGContextFillPath(context)\n"
    }

    public func drawPath(mode: CGPathDrawingMode) {
        source += "CGContextDrawPath(context, TODO)\n"
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

    public var style:Style = Style() {
        didSet {
            source += "CGContextSetStrokeColor(context, TODO)\n"
            source += "CGContextSetFillColor(context, TODO)\n"
        }
    }

}
