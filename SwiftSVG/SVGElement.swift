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
    public internal(set) var textStyle: TextStyle? = nil
    
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

    var fontFamily: String {
        get {
            if let fontFamily = self.textStyle?.fontFamily {
                return fontFamily
            }
            guard let parent = self.parent else {
                return "Helvetica"
            }
            if parent is SVGGroup {
                return parent.fontFamily
            }
            return "Helvetica"
        }
    }

    var fontSize: CGFloat {
        get {
            if let fontSize = self.textStyle?.fontSize {
                return fontSize
            }
            guard let parent = self.parent else {
                return 12
            }
            
            return parent.fontSize
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
    public var viewBox: CGRect?
    public var title: String?
    public var documentDescription: String?
}

// MARK: -

public class SVGGroup: SVGContainer {

}

// MARK: -

public typealias MovingImagesPath = [NSString : AnyObject]
public typealias MovingImagesText = [NSString : AnyObject]

public protocol PathGenerator: CGPathable {
    var mipath:MovingImagesPath { get }
}

public protocol TextRenderer {
    var mitext:MovingImagesText { get }
    var cttext:CFAttributedString { get }
    var textOrigin:CGPoint { get }
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
    public let rx: CGFloat?
    public let ry: CGFloat?

    lazy public var cgpath:CGPath = self.makeCGPath()
    lazy public var mipath:MovingImagesPath = self.makeMIPath()
    
    // http://www.w3.org/TR/SVG/shapes.html#RectElement
    public init(rect: CGRect, rx: CGFloat? = Optional.None, ry: CGFloat? = Optional.None) {
        self.rect = Rectangle(frame: rect)
        if let lrx = rx {
            self.rx = min(lrx, rect.width * 0.5)
            if let lry = ry {
                self.ry = min(lry, rect.height * 0.5)
            }
            else {
                self.ry = min(lrx, rect.height * 0.5) // ry defaults to cx if not defined.
            }
        }
        else if let lry = ry {
            self.ry = min(lry, rect.height * 0.5)
            self.rx = min(lry, rect.width * 0.5) // rx defaults to cy if not defined.
        }
        else {
            self.rx = Optional.None
            self.ry = Optional.None
        }
    }

    public var notRounded: Bool {
        get {
            return self.rx == nil && self.ry == nil
        }
    }
    
    private func makeCGPath() -> CGPath {
        if self.notRounded {
            return self.rect.cgpath
        }
        
        return CGPathCreateWithRoundedRect(self.rect.frame, self.rx!, self.ry!, nil)
    }
    
    private func makeMIPath() -> [NSString : AnyObject] {
        if self.notRounded {
            return makeRectDictionary(rect.frame, hasFill: hasFill, hasStroke: hasStroke)
        }
        return makeRoundedRectDictionary(rect.frame, rx: rx!, ry: ry!, hasFill: hasFill, hasStroke: hasStroke)
        // return makeRectDictionary(rect.frame, hasFill: hasFill, hasStroke: hasStroke)
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
        return makeOvalDictionary(rect, hasFill: hasFill, hasStroke: hasStroke)
    }
}

public class SVGCircle: SVGElement, PathGenerator {
    public let center: CGPoint
    public let radius: CGFloat

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

    private func makeMIPath() -> MovingImagesPath {
        return makeOvalDictionary(rect, hasFill: hasFill, hasStroke: hasStroke)
    }
}

// TODO: There is stuff to be fixed here with the way that font styles are obtained and set.
public class SVGSimpleText: SVGElement, TextRenderer {
    // public let fontFamily: String
    // public let fontSize: CGFloat
    public let string: CFString

    public let textOrigin: CGPoint

    lazy public var mitext:MovingImagesText = self.makeMIText()
    lazy public var cttext:CFAttributedString = self.makeAttributedString()
    
    public init(textOrigin: CGPoint, string: CFString) {
        self.textOrigin = textOrigin
        self.string = string
    }
    
    private func makeAttributedString() -> CFAttributedString {
        var attributes: [NSString : AnyObject] = [
            kCTFontAttributeName : CTFontCreateWithName(self.getPostscriptFontName(), self.fontSize, nil),
        ]
        
        if let fillColor = self.fillColor {
            attributes[kCTForegroundColorAttributeName] = fillColor
        }
        
        if let style = self.style {
            if let strokeColor = style.strokeColor {
                var strokeWidth: CGFloat = 1.0
                if let width = style.lineWidth {
                    strokeWidth = width
                }
                attributes[kCTStrokeColorAttributeName] = strokeColor
                attributes[kCTStrokeWidthAttributeName] = self.fillColor == nil ? strokeWidth : -strokeWidth
            }
        }
        return CFAttributedStringCreate(kCFAllocatorDefault, self.string, attributes)
    }
    
    private func getPostscriptFontName() -> NSString {
        var attributes: [NSString : AnyObject] = [
            kCTFontFamilyNameAttribute : self.fontFamily,
            kCTFontSizeAttribute : self.fontSize,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes)
        if let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) {
            return name as! NSString
        }
        
        // Default to Helvetica.
        attributes[kCTFontFamilyNameAttribute] = "Helvetica"
        let descriptor2 = CTFontDescriptorCreateWithAttributes(attributes)
        return CTFontDescriptorCopyAttribute(descriptor2, kCTFontNameAttribute)! as! NSString
    }
    
    // TODO: The scaling and translation hard coded here needs to be gone.
    // probably moved into the text handler.
    private func makeMIText() -> MovingImagesText {
        var theDict = [
            MIJSONKeyStringPostscriptFontName : self.getPostscriptFontName(),
            MIJSONKeyElementType : MIJSONValueBasicStringElement,
            MIJSONKeyStringText : self.string,
            MIJSONKeyPoint : makePointDictionary(self.textOrigin),
            MIJSONKeyStringFontSize : self.fontSize,
            MIJSONKeyContextTransformation : [
                [
                    MIJSONKeyTransformationType : MIJSONValueTranslate,
                    MIJSONKeyTranslation : [ MIJSONKeyX : 0.0, MIJSONKeyY : 2.0 * self.textOrigin.y ]
                ],
                [
                    MIJSONKeyTransformationType : MIJSONValueScale,
                    MIJSONKeyScale : [ MIJSONKeyX : 1.0, MIJSONKeyY : -1.0 ]
                ]
            ]
        ]
        if let style = self.style, let lineWidth = style.lineWidth {
            theDict[MIJSONKeyStringStrokeWidth] = -lineWidth
        }
        
        // By having a wrapper dictionary the vertical text flipping can't override
        // any other transformations that might be applied to the object.
        let wrapperDict: MovingImagesText = [
            MIJSONKeyElementType : MIJSONValueArrayOfElements,
            MIJSONValueArrayOfElements : [ theDict ]
        ]
        return wrapperDict
    }
}
