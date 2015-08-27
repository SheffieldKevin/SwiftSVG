//
//  SVGTransform.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 3/14/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

import SwiftParsing

func converter(value:Any) -> Any? {

    guard let value = value as? [Any], let type = value[0] as? String, let parameters = value[1] as? [Any] else {
        return nil
    }

    switch type {
        case "matrix":
            let a = parameters[0] as! CGFloat
            let b = parameters[1] as! CGFloat
            let c = parameters[2] as! CGFloat
            let d = parameters[3] as! CGFloat
            let e = parameters[4] as! CGFloat
            let f = parameters[5] as! CGFloat
            return MatrixTransform2D(a: a, b: b, c: c, d: d, tx: e, ty: f)
        case "translate":
            let x = parameters[0] as! CGFloat
            let y = parameters.get(1, defaultValue: CGFloat(0)) as! CGFloat
            return Translate(tx: x, ty: y)
        case "scale":
            let x = parameters[0] as! CGFloat
            let y = parameters.get(1, defaultValue: x) as! CGFloat
            return Scale(sx: x, sy: y)
        case "rotate":
            let angle = parameters[0] as! CGFloat
            let cx = parameters.get(1, defaultValue: CGFloat(0)) as? CGFloat
            let cy = parameters.get(2, defaultValue: CGFloat(0)) as? CGFloat
            return Rotate(angle: angle)
        default:
            return nil
    }
}

let COMMA = Literal(",")
let OPT_COMMA = zeroOrOne(COMMA).makeStripped()
let LPAREN = Literal("(").makeStripped()
let RPAREN = Literal(")").makeStripped()
let VALUE_LIST = oneOrMore((cgFloatValue + OPT_COMMA).makeStripped().makeFlattened())

// TODO: Should set manual min and max value instead of relying on 0..<infinite VALUE_LIST

let matrix = (Literal("matrix") + LPAREN + VALUE_LIST + RPAREN).makeConverted(converter)
let translate = (Literal("translate") + LPAREN + VALUE_LIST + RPAREN).makeConverted(converter)
let scale = (Literal("scale") + LPAREN + VALUE_LIST + RPAREN).makeConverted(converter)
let rotate = (Literal("rotate") + LPAREN + VALUE_LIST + RPAREN).makeConverted(converter)
let skewX = (Literal("skewX") + LPAREN + VALUE_LIST + RPAREN).makeConverted(converter)
let skewY = (Literal("skewY") + LPAREN + VALUE_LIST + RPAREN).makeConverted(converter)
let transform = (matrix | translate | scale | rotate | skewX | skewY).makeFlattened()
let transforms = oneOrMore((transform + OPT_COMMA).makeFlattened())

//rotate(<rotate-angle> [<cx> <cy>]), which specifies a rotation by <rotate-angle> degrees about a given point.
//If optional parameters <cx> and <cy> are not supplied, the rotate is about the origin of the current user coordinate system. The operation corresponds to the matrix [cos(a) sin(a) -sin(a) cos(a) 0 0].
//If optional parameters <cx> and <cy> are supplied, the rotate is about the point (cx, cy). The operation represents the equivalent of the following specification: translate(<cx>, <cy>) rotate(<rotate-angle>) translate(-<cx>, -<cy>).
// 
//skewX(<skew-angle>), which specifies a skew transformation along the x-axis.
// 
//skewY(<skew-angle>), which specifies a skew transformation along the y-axis.

// MARK: -


public func svgTransformAttributeStringToTransform(string: String) throws -> Transform2D? {
    let result = try transforms.parse(string)
    switch result {
        case .Ok(let value):
            guard let value = value as? [Any] else {
                return nil
            }

            let transforms: [Transform] = value.map() {
                return $0 as! Transform
            }

            let compound = CompoundTransform(transforms: transforms)
            return compound
        default:
            break
    }
    return nil

}



