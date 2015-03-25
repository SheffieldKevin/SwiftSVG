//
//  Scratch.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

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

