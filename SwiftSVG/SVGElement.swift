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
    
    public internal(set) var display = true

    var drawFill = true // If fill="none" this explictly turns off fill.
    var fillColor: CGColor? {
        get {
            if !drawFill {
                return nil
            }
            if let color = self.style?.fillColor {
                return color
            }
            guard let parent = self.parent else {
                return nil
            }
            
            if parent is SVGGroup {
                return parent.fillColor
            }
            
            if parent is SVGDocument {
                return try! SVGColors.stringToColor("black")
            }
            return nil
        }
    }
    
    var hasFill: Bool {
        get { return self.fillColor != nil }
    }

    // Different default behaviour for fill and stroke. Default fill is to draw
    // black, while default stroke is not drawing anything.
    var strokeColor: CGColor? {
        get {
            if let color = self.style?.strokeColor {
                return color
            }
            guard let parent = self.parent else {
                return nil
            }
            
            if parent is SVGGroup {
                return parent.strokeColor
            }
            return nil
        }
    }

    var hasStroke: Bool {
        get { return self.strokeColor != nil }
    }

    var numParents: Int {
        if let parent = parent {
            return parent.numParents + 1
        }
        return 0
    }

    final func printElement()
    {
        var description = "================================================================\n"
        description += "Element with numParents: \(numParents) \n"
        if let id = id { description += "id: \(id). " }
        description += "type: \(self.dynamicType). "
        if let _ = self.style { description += "Has style. " }
        if let _ = self.transform { description += "Has transform. " }
        print(description)
    }
    
    func printElements() {
        printElement()
    }
    
    func printSelfAndParents() {
        for var parent:SVGElement? = self; parent != nil; parent = parent!.parent {
            parent?.printElement()
        }
    }

// MARK: MovingImages start.
    public internal(set) var movingImages = [NSString : AnyObject]()
    
    func updateMovingImagesJSON() {
        updateMovingImagesElementType(self)
    }

    public func generateMovingImagesJSON() -> [NSString : AnyObject] {
        return self.movingImages
    }

    // This is on SVGElement and not SVGPath because a group with styles set
    // might contain children with paths.
    final func getPathElementType() -> String? {
        let hasStroke = self.hasStroke
        let hasFill = self.hasFill
        guard hasStroke || hasFill else {
            return nil
        }
        return hasFill ? (hasStroke ? MIJSONValuePathFillAndStrokeElement : MIJSONValuePathFillElement) : MIJSONValuePathStrokeElement
    }

// MARK: MovingImages end.
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
    
    override func printElements() {
        self.printElement()
        self.children.forEach() { $0.printElements() }
    }
    
// MARK: MovingImages start.
    override public func generateMovingImagesJSON() -> [NSString : AnyObject] {
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
        
        var elementsArray = [AnyObject]()
        self.children.forEach() {
            if $0.display {
                let movingImagesJSON = $0.generateMovingImagesJSON()
                // only add elements to array of elements if they have a type.
                if let _ = movingImagesJSON[MIJSONKeyElementType] {
                    elementsArray.append($0.generateMovingImagesJSON())
                }
            }
        }
        
        if elementsArray.count != 0 {
            jsonDict[MIJSONKeyElementType] = MIJSONValueArrayOfElements
            jsonDict[MIJSONValueArrayOfElements] = elementsArray
        }
        return jsonDict
    }
    
    override func updateMovingImagesJSON() {
        self.children.forEach() {
            if $0.display {
                $0.updateMovingImagesJSON()
            }
        }
    }
// MARK: MovingImages end.
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

public typealias MovingImagesPath = [NSString : AnyObject]

public protocol PathGenerator: CGPathable {
    var mipath:MovingImagesPath { get }
}

// MARK: -

public class SVGPath: SVGElement, PathGenerator {
    public private(set) var cgpath: CGPath
    public private(set) var mipath: MovingImagesPath

    public init(path: CGPath, miPath: MovingImagesPath) {
        self.cgpath = path
        self.mipath = miPath
    }
    
    // Returns true on success. False on failure. Used when combining elements.
    internal func addPath(svgPath: SVGPath) -> Bool {
        let miPath1 = self.mipath[MIJSONKeyArrayOfPathElements] as? [[NSString : AnyObject]]
        let miPath2 = svgPath.mipath[MIJSONKeyArrayOfPathElements] as? [[NSString : AnyObject]]
        if let miPath1 = miPath1, let miPath2 = miPath2 {
            self.cgpath = self.cgpath + svgPath.cgpath
            self.mipath[MIJSONKeyArrayOfPathElements] = miPath1 + miPath2
            return true
        }
        else {
            return false
        }
    }
}

public class SVGLine: SVGElement, PathGenerator {
    public let startPoint: CGPoint
    public let endPoint: CGPoint

    lazy public var cgpath: CGPath = self.makePath()
    lazy public var mipath: MovingImagesPath = makeLineDictionary(self.startPoint, endPoint: self.endPoint)

    public init(startPoint: CGPoint, endPoint: CGPoint) {
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    private func makePath() -> CGPath {
        let localPath = CGPathCreateMutable()
        localPath.move(startPoint)
        localPath.addLine(endPoint)
        localPath.close()
        return localPath
    }
}

public class SVGPolygon: SVGElement, PathGenerator {
    public let polygon:SwiftGraphics.Polygon
    
    lazy public var cgpath:CGPath = self.polygon.cgpath
    lazy public var mipath:MovingImagesPath = makePolygonDictionary(self.polygon.points)
    
    public init(points: [CGPoint]) {
        self.polygon = SwiftGraphics.Polygon(points: points)
    }
}

public class SVGPolyline: SVGElement, PathGenerator {
    public let points: [CGPoint]
    
    lazy public var cgpath:CGPath = self.makePath()
    lazy public var mipath:MovingImagesPath = makePolylineDictionary(self.points)
    
    public init(points: [CGPoint]) {
        self.points = points
    }
    
    private func makePath() -> CGPath {
        let localPath = CGPathCreateMutable()
        CGPathAddLines(localPath, nil, points, points.count)
        return localPath
    }
}

public class SVGRect: SVGElement, PathGenerator {
    public let rect: Rectangle
    lazy public var cgpath:CGPath = self.rect.cgpath
    lazy public var mipath:MovingImagesPath = self.makeMIPath()
    
    public init(rect: CGRect) {
        self.rect = Rectangle(frame: rect)
    }

    private func makeMIPath() -> [NSString : AnyObject] {
        return makeRectDictionary(rect.frame, makePath: hasFill && hasStroke)
    }
}

public class SVGEllipse: SVGElement, PathGenerator {
    public var rect: CGRect!
    
    lazy public var cgpath:CGPath = CGPathCreateWithEllipseInRect(self.rect, nil)
    lazy public var mipath:MovingImagesPath = self.makeMIPath()
    
    public init(rect: CGRect) {
        self.rect = rect
    }
    
    private func makeMIPath() -> [NSString : AnyObject] {
        return makeRectDictionary(rect, makePath: hasFill && hasStroke)
    }
}

public class SVGCircle: SVGElement, PathGenerator {
    public var center: CGPoint!
    public var radius: CGFloat!

    lazy public var cgpath:CGPath = CGPathCreateWithEllipseInRect(self.rect, nil)
    lazy public var mipath:MovingImagesPath = self.makeMIPath()
    
    public var rect: CGRect {
        let rectSize = CGSize(width: 2.0 * radius, height: 2.0 * radius)
        let rectOrigin = CGPoint(x: center.x - radius, y: center.y - radius)
        return CGRect(origin: rectOrigin, size: rectSize)
    }

    public init(center: CGPoint, radius: CGFloat) {
        self.center = center
        self.radius = radius
    }

    private func makeMIPath() -> [NSString : AnyObject] {
        return makeRectDictionary(rect, makePath: hasFill && hasStroke)
    }
}
