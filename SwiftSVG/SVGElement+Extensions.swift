//
//  SVGElement+Extensions.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 3/13/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import SwiftUtilities

extension SVGElement {

    static var walker: Walker <SVGElement> {
        let walker = Walker() {
            (node:SVGElement) -> [SVGElement]? in
            if let node = node as? SVGContainer {
                return node.children
            }
            else {
                return nil
            }
        }
        return walker
    }

    var indexPath: NSIndexPath {
        get {

            if let parent = parent {
                let index = find(parent.children, self)!
                return parent.indexPath.indexPathByAddingIndex(index)
            }
            else {
                return NSIndexPath(index: 0)
            }
        }
    }

}