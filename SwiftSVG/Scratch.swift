//
//  Scratch.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation
import SwiftGraphics

func + (lhs:SwiftGraphics.Style, rhs:SwiftGraphics.Style) -> SwiftGraphics.Style {
    var accumulator = lhs
    accumulator.add(rhs.asStyleElements())
    return accumulator
}

extension SwiftGraphics.Style {

    init() {
        self.init(elements:[])
    }

    var isEmpty:Bool {
        get {
            return asStyleElements().count == 0
        }
    }

    func asStyleElements() -> [StyleElement] {

        var elements:[StyleElement] = []

        if let fillColor = fillColor {
            elements.append(.fillColor(fillColor))
        }

        if let strokeColor = strokeColor {
            elements.append(.fillColor(strokeColor))
        }

        if let lineWidth = lineWidth {
            elements.append(.lineWidth(lineWidth))
        }

        if let lineCap = lineCap {
            elements.append(.lineCap(lineCap))
        }

        if let lineJoin = lineJoin {
            elements.append(.lineJoin(lineJoin))
        }

        if let miterLimit = miterLimit {
            elements.append(.miterLimit(miterLimit))
        }

        if let lineDash = lineDash {
            elements.append(.lineDash(lineDash))
        }

        if let lineDashPhase = lineDashPhase {
            elements.append(.lineDashPhase(lineDashPhase))
        }

        if let flatness = flatness {
            elements.append(.flatness(flatness))
        }

        if let alpha = alpha {
            elements.append(.alpha(alpha))
        }

        if let blendMode = blendMode {
            elements.append(.blendMode(blendMode))
        }

        return elements
    }
}

extension Array {
    func get(index:Int, defaultValue:T) -> T {
        if index < count {
            return self[index]
        }
        else {
            return defaultValue
        }
    }
}

extension NSXMLElement {

    subscript(name:String) -> NSXMLNode? {
        get {
            return attributeForName(name)
        }
        set {
            if let newValue = newValue {
                fatalError("OOPS")
            }
            else {
                removeAttributeForName(name)
            }
        }
    }
}

struct Event {
    enum Severity {
        case debug
        case info
        case warning
        case error
    }

    let severity:Severity
    let message:String
}

extension Event: Printable {
    var description: String {
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

