//  File.swift
//  SwiftSVG
//
//  Created by Kevin Meaney on 08/10/2015.
//  Copyright © 2015 No. All rights reserved.

import Foundation

import XCTest
@testable import SwiftSVG

func jsonFromNamedFile(namedFile: String) throws -> String {
    let textDrawingURL = try makeURLFromNamedFile(namedFile, fileExtension: "json")
    var encoding = NSStringEncoding()
    guard let source = try? String(contentsOfURL: textDrawingURL, usedEncoding: &encoding) else {
        throw TestError.noContentInFile(textDrawingURL.path!)
    }
    return source
}

class MovingImagesSVGTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testTextDrawing() {
        let optionalSVGDocument: SVGDocument?
        let originalJSONString: String
        do {
            let xmlDocument = try xmlDocumentFromNamedSVGFile("TextDrawing")
            let processor = SVGProcessor()
            optionalSVGDocument = try processor.processXMLDocument(xmlDocument)
            originalJSONString = try jsonFromNamedFile("TextDrawing")
        }
        catch let error {
            print(error)
            return
        }
        
        guard let svgDocument = optionalSVGDocument else {
            XCTAssert(false, "optionalSVGDocument should not be .None")
            return
        }
        
        let renderer = MovingImagesRenderer()
        let svgRenderer = SVGRenderer()
        let _ = try? svgRenderer.renderDocument(svgDocument, renderer: renderer)
        let jsonObject = renderer.generateJSONDict()

        guard let jsonString = jsonObjectToString(jsonObject) else {
            return
        }
        XCTAssert(originalJSONString == jsonString,
            "MovingImages JSON Text rendering representation changed")
        print(jsonString)
        print(originalJSONString)
    }
}
