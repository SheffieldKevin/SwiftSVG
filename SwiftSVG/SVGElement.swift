//
//  SVGDocument.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics

// MARK: -

public protocol Node {
    typealias ParentType
    var parent: ParentType? { get }
}

public protocol GroupNode: Node {
    typealias NodeType
    var children: [NodeType] { get }
}

// MARK: -

public class SVGElement: Node {
    public typealias ParentType = SVGContainer
    public weak var parent: SVGContainer? = nil
    public internal(set) var style: SwiftGraphics.Style? = nil
    public internal(set) var transform: Transform2D? = nil
    public let uuid = NSUUID() // TODO: This is silly.
    public internal(set) var id: String? = nil
    public internal(set) var xmlElement: NSXMLElement? = nil
}

extension SVGElement: Equatable {
}

public func == (lhs: SVGElement, rhs: SVGElement) -> Bool {
    return lhs === rhs
}

extension SVGElement: Hashable {
    public var hashValue: Int {
        return uuid.hash
    }
}

// MARK: -

public class SVGContainer: SVGElement, GroupNode {
    public var children: [SVGElement] = []

    public func replace(oldElement: SVGElement, with newElement: SVGElement) throws {

        guard let index = children.indexOf(oldElement) else {
            // TODO: throw
            fatalError("BOOM")
        }

        oldElement.parent = nil
        children[index] = newElement
        newElement.parent = self
    }
}

// MARK: -

public class SVGDocument: SVGContainer {

    public enum Profile {
        case full
        case tiny
        case basic
    }

    public struct Version {
        let majorVersion: Int
        let minorVersion: Int
    }

    public var profile: Profile?
    public var version: Version?
    public var viewBox: CGRect!
    public var title: String?
    public var documentDescription: String?
}

// MARK: -

public class SVGGroup: SVGContainer {
}

// MARK: -

public protocol SVGGeometryNode: Node {
    var drawable: Drawable { get }
}

// MARK: -

public class SVGPath: SVGElement, CGPathable {
    public internal(set) var cgpath: CGPath
    public init(path: CGPath) {
        self.cgpath = path
    }
}