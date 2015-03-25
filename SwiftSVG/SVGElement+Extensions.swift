//
//  SVGElement+Extensions.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 3/13/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation

extension SVGElement {

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