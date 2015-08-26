//
//  SVGModifier.swift
//  SwiftSVG
//
//  Created by Jonathan Wight on 8/26/15.
//  Copyright © 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics

public extension SVGContainer {

    func optimise() {
        flatten()
        combine()
    }

    func flatten() {

        // TODO: Search for references to remove group

        // Don't modify tree as we're walking it - so keep a list of groups to flatten
        var parents: [SVGGroup] = []

        // Find group elements with exactly 1 child
        SVGElement.walker.walk(self) {
            (element: SVGElement, depth: Int) -> Void in
            if let group = element as? SVGGroup where group.children.count == 1 {
                parents.append(group)
            }
        }

        // Now process the found groups
        for parent in parents {

            let child = parent.children[0]

            // Concat the parent style with the child style
            let style = (parent.style ?? Style()) + (child.style ?? Style())
            if style.isEmpty == false {
                child.style = style
            }

            // Concat the parent transform with the child transform
            let transform = (parent.transform ?? IdentityTransform()) + (child.transform ?? IdentityTransform())
            if transform.isIdentity == false {
                child.transform = transform
            }

            // Replace the parent with the child
            if let grandParent = parent.parent {
                try! grandParent.replace(parent, with: child)
            }
        }

    }

    func combine() {

        for child in children {
            if let container = child as? SVGContainer {
                container.combine()
            }
        }

        var combinedFlag = false

        repeat {
            combinedFlag = false
            var lastChild: SVGElement?
            for (index, child) in children.enumerate() {
                if let lastChild = lastChild {
                    guard let child = child as? SVGPath, let lastChild = lastChild as? SVGPath else {
                        continue
                    }

                    guard child.style == lastChild.style else {
                        continue
                    }

                    guard child.transform?.asCGAffineTransform() == lastChild.transform?.asCGAffineTransform() else {
                        continue
                    }

                    let newPath = lastChild.cgpath + child.cgpath
                    lastChild.cgpath = newPath

                    children.removeAtIndex(index)

                    combinedFlag = true
                    break

                }
                lastChild = child
            }
        }
        while combinedFlag == true


    }
}

func + (lhs:CGPath, rhs:CGPath) -> CGPath {
    let path = CGPathCreateMutableCopy(lhs)!
    CGPathAddPath(path, nil, rhs)
    return path
}


extension CGColor {
    var components:[CGFloat] {
        let count = CGColorGetNumberOfComponents(self)
        let componentsPointer = CGColorGetComponents(self)
        let components = UnsafeBufferPointer <CGFloat> (start:componentsPointer, count:count)
        return Array <CGFloat> (components)
    }

    var alpha:CGFloat {
        return CGColorGetAlpha(self)
    }

    var colorSpace:CGColorSpace? {
        return CGColorGetColorSpace(self)
    }

    var colorSpaceName:String? {
        return CGColorSpaceCopyName(self.colorSpace) as? String
    }

}

extension CGColor: CustomReflectable {
    public func customMirror() -> Mirror {
        return Mirror(self, children: [
            "alpha": alpha,
            "colorSpace": colorSpaceName,
            "components": components,
        ])
    }
}

extension CGColor: Equatable {
}

public func ==(lhs: CGColor, rhs: CGColor) -> Bool {

    if lhs.alpha != rhs.alpha {
        return false
    }
    if lhs.colorSpaceName != rhs.colorSpaceName {
        return false
    }
    if lhs.components != rhs.components {
        return false
    }

    return true
}

extension Style: Equatable {
}

public func ==(lhs: Style, rhs: Style) -> Bool {
    if lhs.fillColor != rhs.fillColor {
        return false
    }
    if lhs.strokeColor != rhs.strokeColor {
        return false
    }
    if lhs.lineWidth != rhs.lineWidth {
        return false
    }
    if lhs.lineCap != rhs.lineCap {
        return false
    }
    if lhs.miterLimit != rhs.miterLimit {
        return false
    }
    if lhs.lineDash ?? [] != rhs.lineDash ?? [] {
        return false
    }
    if lhs.lineDashPhase != rhs.lineDashPhase {
        return false
    }
    if lhs.flatness != rhs.flatness {
        return false
    }
    if lhs.alpha != rhs.alpha {
        return false
    }
    if lhs.blendMode != rhs.blendMode {
        return false
    }
    return true
}

extension Style: CustomReflectable {
    public func customMirror() -> Mirror {
        return Mirror(self, children: [
            "hello": "world"
        ])
    }
}
