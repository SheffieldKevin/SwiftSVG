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

public func jsonObjectToString(jsonObject: AnyObject) -> String? {
    if NSJSONSerialization.isValidJSONObject(jsonObject) {
        let data = try? NSJSONSerialization.dataWithJSONObject(jsonObject,
            options: NSJSONWritingOptions.PrettyPrinted)
        if let data = data,
            let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                return jsonString as String
        }
    }
    return nil
}

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
    
    func generateMovingImagesJSON() -> [NSString : AnyObject] {
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
    
    override func generateMovingImagesJSON() -> [NSString : AnyObject] {
        var elementsArray = [AnyObject]()
        if self.children.count == 0 {
            return self.movingImages
        }
        
        if self.children.count == 1 {
            if let svgPathElement = self.children[0] as? SVGPath {
                if svgPathElement.style == Optional.None {
                    self.movingImages[MIJSONKeyArrayOfPathElements] = svgPathElement.movingImages[MIJSONKeyArrayOfPathElements]
                    self.movingImages[MIJSONKeyStartPoint] = svgPathElement.movingImages[MIJSONKeyStartPoint]
                    return self.movingImages
                }
            }
        }
        
        self.children.forEach() {
            elementsArray.append($0.generateMovingImagesJSON())
        }
        self.movingImages[MIJSONKeyElementType] = MIJSONValueArrayOfElements
        self.movingImages[MIJSONValueArrayOfElements] = elementsArray
        return self.movingImages
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