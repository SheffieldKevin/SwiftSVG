//
//  main.swift
//  Transform
//
//  Created by Jonathan Wight on 3/15/15.
//  Copyright (c) 2015 schwa.io. All rights reserved.
//

import Foundation
import QuartzCore

protocol Transform {
    var isIdentity:Bool { get }
}

protocol Transform2D: Transform {
    func asCGAffineTransform() -> CGAffineTransform!
}

protocol Transform3D: Transform {
    func asCATransform3D() -> CATransform3D!
}

// MARK: -

struct IdentityTransform: Transform {
    var isIdentity:Bool {
        get {
            return true
        }
    }
}

extension IdentityTransform: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {
        return CGAffineTransformIdentity
    }
}

// MARK: -

struct CompoundTransform: Transform {
    let transforms:[Transform]

    init(transforms:[Transform]) {
        // TODO: Check that all transforms are also Transform2D? Or use another init?



        // TODO: Strip out identity transforms
        self.transforms = transforms.filter() {
            return $0.isIdentity == false
        }
    }

    var isIdentity:Bool {
        get {
            if transforms.count == 0 {
                return true
            }
            else {
                // TODO: LIE
                return false
            }
        }
    }
}

extension CompoundTransform: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {

        // Convert all transforms to 2D transforms. We will explode if not all transforms are 2D capable
        let affineTransforms:[CGAffineTransform] = transforms.map{
            return ($0 as! Transform2D).asCGAffineTransform()
        }

        let transform:CGAffineTransform = affineTransforms[0]
        let result:CGAffineTransform = affineTransforms[1..<affineTransforms.count].reduce(transform) {
            (lhs:CGAffineTransform, rhs:CGAffineTransform) -> CGAffineTransform in
            return CGAffineTransformConcat(lhs, rhs)
        }
        return result
    }
}

func + (lhs:Transform, rhs:Transform) -> CompoundTransform {
    return CompoundTransform(transforms: [lhs, rhs])
}

func + (lhs:CompoundTransform, rhs:Transform) -> CompoundTransform {
    return CompoundTransform(transforms: lhs.transforms + [rhs])
}

func + (lhs:Transform, rhs:CompoundTransform) -> CompoundTransform {
    return CompoundTransform(transforms: [lhs] + rhs.transforms)
}

func + (lhs:CompoundTransform, rhs:CompoundTransform) -> CompoundTransform {
    return CompoundTransform(transforms: lhs.transforms + rhs.transforms)
}

extension CompoundTransform: CustomStringConvertible {
    var description: String {
        get {
            let transformStrings:[String] = transforms.map() { return String($0) }
            return "CompoundTransform(\(transformStrings))"
        }
    }
}

// MARK: -

struct MatrixTransform2D: Transform {
    let a:CGFloat
    let b:CGFloat
    let c:CGFloat
    let d:CGFloat
    let tx:CGFloat
    let ty:CGFloat

    var isIdentity:Bool {
        get {
            // TODO: LIE
            return false
        }
    }
}

extension MatrixTransform2D: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {
        return CGAffineTransformMake(a, b, c, d, tx, ty)
    }
}

extension MatrixTransform2D: CustomStringConvertible {
    var description: String {
        get {
            return "Matrix(\(a), \(b), \(c) \(d), \(tx), \(ty))"
        }
    }
}

// MARK: Translate

struct Translate: Transform {
    let tx:CGFloat
    let ty:CGFloat
    let tz:CGFloat

    init(tx:CGFloat, ty:CGFloat, tz:CGFloat = 0.0) {
        self.tx = tx
        self.ty = ty
        self.tz = tz
    }

    var isIdentity:Bool {
        get {
            // TODO: LIE
            return false
        }
    }
}

extension Translate: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {
        return tz == 0.0 ? CGAffineTransformMakeTranslation(tx, ty) : nil
    }
}

extension Translate: Transform3D {
    func asCATransform3D() -> CATransform3D! {
        return CATransform3DMakeTranslation(tx, ty, tz)
    }
}

extension Translate: CustomStringConvertible {
    var description: String {
        get {
            return "Translate(\(tx), \(ty), \(tz))"
        }
    }
}

// MARK: Scale

struct Scale: Transform {
    let sx:CGFloat
    let sy:CGFloat
    let sz:CGFloat

    init(sx:CGFloat, sy:CGFloat, sz:CGFloat = 1) {
        self.sx = sx
        self.sy = sy
        self.sz = sz
    }

    init(scale:CGFloat) {
        sx = scale
        sy = scale
        sz = scale
    }

    var isIdentity:Bool {
        get {
            // TODO: LIE
            return false
        }
    }
}

extension Scale: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {
        return sz == 1.0 ? CGAffineTransformMakeScale(sx, sy) : nil
    }
}

extension Scale: Transform3D {
    func asCATransform3D() -> CATransform3D! {
        return CATransform3DMakeScale(sx, sy, sz)
    }
}

extension Scale: CustomStringConvertible {
    var description: String {
        get {
            return "Scale(\(sx), \(sy), \(sz))"
        }
    }
}

// MARK: -

struct Rotate: Transform {
    let angle:CGFloat
    // AXIS, TRANSLATION

    var isIdentity:Bool {
        get {
            // TODO: LIE
            return false
        }
    }
}

extension Rotate: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {
        return CGAffineTransformMakeRotation(angle)
    }
}

extension Rotate: CustomStringConvertible {
    var description: String {
        get {
            return "Rotate(\(angle))"
        }
    }
}

// MARK: -

struct Skew: Transform {
    let angle:CGFloat
    // AXIS

    var isIdentity:Bool {
        get {
            // TODO: LIE
            return false
        }
    }
}

extension Skew: Transform2D {
    func asCGAffineTransform() -> CGAffineTransform! {
        assertionFailure("Cannot skew")
        return nil
    }
}

extension Skew: CustomStringConvertible {
    var description: String {
        get {
            return "Skew(\(angle))"
        }
    }
}

