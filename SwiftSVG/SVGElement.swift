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
    
    public internal(set) var movingImages = [NSString : AnyObject]()
    
    var numParents: Int {
        if let parent = parent {
            return parent.numParents + 1
        }
        return 0
    }

    func printElement()
    {
        var description = "================================================================\n"
        description += "Element with numParents: \(numParents) \n"
        if let id = id {
            description += "id: \(id). "
        }
        if let _ = self as? SVGContainer {
            description += "base type: container. "
            if let _ = self as? SVGGroup {
                description += "type: group. "
            }
            if let _ = self as? SVGDocument {
                description += "type: document. "
            }
        }

        if let _ = self.style {
            description += "Has style. "
        }
        
        if let _ = self.transform {
            description += "Has transform. "
        }
        
        if let _ = self as? SVGPath {
            description += "type: path.\n"
        }

        print(description)
    }
    
    public func generateMovingImagesJSON() -> [NSString : AnyObject] {
        return self.movingImages
    }
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

// MARK: MovingImages customizations.

extension SVGElement {
    final func hasProperty(property: NSString) -> Bool {
        if let _ = self.movingImages[property] {
            return true
        }
        else {
            return false
        }
    }

    // This is on SVGElement and not SVGPath because a group with styles set
    // might contain a single path child.
    final func getPathElementType() -> String? {
        let hasStroke = self.hasProperty(MIJSONKeyStrokeColor)
        let hasFill = self.hasProperty(MIJSONKeyFillColor)
        guard hasStroke || hasFill else {
            return nil
        }
        return hasFill ? (hasStroke ? MIJSONValuePathFillAndStrokeElement : MIJSONValuePathFillElement) : MIJSONValuePathStrokeElement
    }
}

// MARK: -

public class SVGContainer: SVGElement, GroupNode {
    public var children: [SVGElement] = [] {
        didSet {
            children.forEach() { $0.parent = self }
        }
    }

    override init() {
        super.init()
    }

    public convenience init(children:[SVGElement]) {
        self.init()
        self.children = children
        self.children.forEach() { $0.parent = self }
    }

    public func replace(oldElement: SVGElement, with newElement: SVGElement) throws {

        guard let index = children.indexOf(oldElement) else {
            // TODO: throw
            fatalError("BOOM")
        }

        oldElement.parent = nil
        children[index] = newElement
        newElement.parent = self
    }
    
    override func printElement() {
        super.printElement()
        self.children.forEach() { $0.printElement() }
    }
    
    override public func generateMovingImagesJSON() -> [NSString : AnyObject] {
        var elementsArray = [AnyObject]()
        if self.children.count == 0 {
            return self.movingImages
        }
        
        var jsonDict = self.movingImages
        if self.children.count == 1 {
            if let svgPathElement = self.children[0] as? SVGPath {
                if svgPathElement.style == Optional.None {
                    jsonDict[MIJSONKeyArrayOfPathElements] = svgPathElement.movingImages[MIJSONKeyArrayOfPathElements]
                    jsonDict[MIJSONKeyStartPoint] = svgPathElement.movingImages[MIJSONKeyStartPoint]
                    if jsonDict[MIJSONKeyElementType] == nil {
                        jsonDict[MIJSONKeyElementType] = self.getPathElementType()
                    }
                    return jsonDict
                }
            }
        }
        
        self.children.forEach() {
            elementsArray.append($0.generateMovingImagesJSON())
        }
        jsonDict[MIJSONKeyElementType] = MIJSONValueArrayOfElements
        jsonDict[MIJSONValueArrayOfElements] = elementsArray
        return jsonDict
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

public class SVGPath: SVGElement, CGPathable {
    public internal(set) var cgpath: CGPath

    public init(path: CGPath) {
        self.cgpath = path
    }
}


public class SVGLine: SVGElement {
    public var startPoint: CGPoint!
    public var endPoint: CGPoint!
    
    public init(startPoint: CGPoint, endPoint: CGPoint) {
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

public class SVGRect: SVGElement {
    public var rect: CGRect!
    
    public init(rect: CGRect) {
        self.rect = rect
    }
}

public class SVGCircle: SVGElement {
    public var center: CGPoint!
    public var radius: CGFloat!

    public var rect: CGRect {
        let rectSize = CGSize(width: 2.0 * radius, height: 2.0 * radius)
        let rectOrigin = CGPoint(x: center.x - radius, y: center.y - radius)
        return CGRect(origin: rectOrigin, size: rectSize)
    }

    public init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }
}
