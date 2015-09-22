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

    func addPath(path:CGPath)
    func fillPath()
    func drawPath(mode: CGPathDrawingMode)
    func drawLine(startPoint: CGPoint, endPoint: CGPoint)
    func fillCircle(rect: CGRect)
    func strokeCircle(rect: CGRect)
    func fillRect(rect: CGRect)
    func strokeRect(rect: CGRect)

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

    public func pushGraphicsState() {
        CGContextSaveGState(self)
    }

    public func restoreGraphicsState() {
        CGContextRestoreGState(self)
    }

    public func addPath(path:CGPath) {
        CGContextAddPath(self, path)
    }

    public func fillPath() {
        CGContextFillPath(self)
    }

    public func fillCircle(rect: CGRect) {
        CGContextFillEllipseInRect(self, rect)
    }

    public func strokeCircle(rect: CGRect) {
        CGContextStrokeEllipseInRect(self, rect)
    }

    public func fillRect(rect: CGRect) {
        CGContextFillRect(self, rect)
    }
    
    public func strokeRect(rect: CGRect) {
        CGContextStrokeRect(self, rect)
    }

    public func drawPath(mode: CGPathDrawingMode) {
        CGContextDrawPath(self, mode)
    }

    public func drawLine(startPoint: CGPoint, endPoint: CGPoint) {
        CGContextBeginPath(self)
        CGContextMoveToPoint(self, startPoint.x, startPoint.y)
        CGContextAddLineToPoint(self, endPoint.x, endPoint.y)
        CGContextClosePath(self)
        CGContextStrokePath(self)
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

    public func pushGraphicsState() {
        source += "CGContextSaveGState(context)\n"
    }
    
    public func restoreGraphicsState() {
        source += "CGContextRestoreGState(self)\n"
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

    public func drawLine(startPoint: CGPoint, endPoint: CGPoint) {
        source += "CGContextBeginPath(context)\n" +
                  "CGContextMoveToPoint(context, TODO)\n" +
                  "CGContextAddLineToPoint(context, TODO, TODO)\n" +
                  "CGContextClosePath(context)\n" +
                  "CGContextStrokePath(context)\n"
    }

    public func fillCircle(rect: CGRect) {
        source += "CGContextFillEllipseInRect(context, TODO)\n"
    }
    
    public func strokeCircle(rect: CGRect) {
        source += "CGContextStrokeEllipseInRect(context, TODO)\n"
    }

    public func fillRect(rect: CGRect) {
        source += "CGContextFillRect(context, TODO)\n"
    }
    
    public func strokeRect(rect: CGRect) {
        source += "CGContextStrokeRect(context, TODO)\n"
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
