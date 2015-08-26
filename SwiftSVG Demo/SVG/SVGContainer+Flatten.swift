//
//  SVGModifier.swift
//  SwiftSVG
//
//  Created by Jonathan Wight on 8/26/15.
//  Copyright © 2015 No. All rights reserved.
//

import Foundation

import SwiftGraphics

extension SVGContainer {

    func flatten() {

        // TODO: Search for references to remove group

        // Don't modify tree as we're walking it - so keep a list of groups to flatten
        var parents:[SVGGroup] = []

        // Find group elements with exactly 1 child
        SVGElement.walker.walk(self) {
            (element:SVGElement, depth: Int) -> Void in
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

}
