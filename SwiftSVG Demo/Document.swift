//
//  Document.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Cocoa

import SwiftSVG

class Document: NSDocument {

    dynamic var source: String? = nil {
        didSet {
            if source != oldValue {
                print(try? parse())
            }
        }
    }
    var svgDocument: SVGDocument? = nil

    override init() {
        super.init()
    }

    override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        if let controller = aController.contentViewController as? ViewController {
            controller.document = self
        }
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! NSWindowController
        if let controller = windowController.contentViewController as? ViewController {
            controller.document = self
        }
        self.addWindowController(windowController)
    }

    override func readFromURL(url: NSURL, ofType typeName: String) throws {
        var encoding = NSStringEncoding()
        source = try String(contentsOfURL: url, usedEncoding: &encoding)
    }

    func parse() throws {
        guard let source = source else {
            return
        }

        let xmlDocument = try NSXMLDocument(XMLString: source, options: 0)
        let processor = SVGProcessor()
        svgDocument = try processor.processXMLDocument(xmlDocument)

//        let renderer = SourceCodeRenderer()
//        let svgRenderer = SVGRenderer()
//        try svgRenderer.renderDocument(svgDocument!, renderer: renderer)
//        print(renderer.source)

    }

}

