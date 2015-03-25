//
//  AppDelegate.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(aNotification: NSNotification) {

        let url = NSBundle.mainBundle().URLForResource("Ghostscript_Tiger", withExtension: "svg")
        (NSDocumentController.sharedDocumentController() as! NSDocumentController).openDocumentWithContentsOfURL(url!, display: true) {
            (document:NSDocument!, flag:Bool, error:NSError!) in
        }

    }
}

