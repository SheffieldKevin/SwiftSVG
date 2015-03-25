//
//  SVGDocument.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics

protocol Node {
    typealias ParentType
    var parent:ParentType? { get }
}

protocol GroupNode: Node {
    typealias NodeType
    var children:[NodeType] { get }
}

// MARK: -

class SVGElement: Node {
    typealias ParentType = SVGContainer
    weak var parent:SVGContainer? = nil
    var style:SwiftGraphics.Style? = nil
    var transform:CGAffineTransform? = nil
    var uuid = NSUUID() // TODO: This is silly.
    var id:String? = nil
    var xmlElement:NSXMLElement? = nil

    func dump(depth:Int = 0) {
        let padding = ("" as NSString).stringByPaddingToLength(depth, withString: " ", startingAtIndex: 0)
        let description = toString(self)
        println("\(padding)\(description)")
    }
}

extension SVGElement: Equatable {
}

func == (lhs:SVGElement, rhs:SVGElement) -> Bool {
    return lhs === rhs
}


extension SVGElement: Hashable {
    var hashValue: Int {
        return uuid.hash
    }

}

class SVGContainer: SVGElement, GroupNode {
    var children:[SVGElement] = []
}

class SVGDocument: SVGContainer {

    enum Profile {
        case full
        case tiny
        case basic
    }

    struct Version {
        let majorVersion:Int
        let minorVersion:Int
    }

    var profile:Profile?
    var version:Version?
    var viewBox:CGRect!
    var title:String?
    var documentDescription:String?

    override func dump(depth:Int = 0) {
        super.dump(depth: depth)
        for child in children {
            child.dump(depth: depth + 1)
        }
    }
}

class SVGGroup: SVGContainer {
    override func dump(depth:Int = 0) {
        super.dump(depth: depth)
        for child in children {
            child.dump(depth: depth + 1)
        }
    }
}

protocol SVGGeometryNode: Node {
    var drawable:Drawable { get }
}

class SVGPath: SVGElement, CGPathable {
    let cgpath:CGPath
    init(path:CGPath) {
        self.cgpath = path
    }
}