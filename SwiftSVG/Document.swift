//
//  Document.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Cocoa

class Document: NSDocument {

    var svgDocument:SVGDocument? = nil

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        if let controller = aController.contentViewController as? ViewController {
            controller.svgDocument = svgDocument
        }
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! NSWindowController
        if let controller = windowController.contentViewController as? ViewController {
            controller.svgDocument = svgDocument
        }
        self.addWindowController(windowController)
    }

    override func readFromData(data: NSData, ofType typeName: String) throws {

        let xmlDocument: NSXMLDocument?
        do {
            xmlDocument = try NSXMLDocument(data: data, options: 0)
        } catch _ {
            xmlDocument = nil
        }

        let processor = SVGProcessor()

        svgDocument = processor.processXMLDocument(xmlDocument!)
    }


}

