//
//  Scratch.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Foundation
import SwiftGraphics

extension Array {
    func get(index: Int, defaultValue: Element) -> Element {
        if index < count {
            return self[index]
        }
        else {
            return defaultValue
        }
    }
}
