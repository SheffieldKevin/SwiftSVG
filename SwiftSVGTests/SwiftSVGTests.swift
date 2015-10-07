//
//  SwiftSVGTests.swift
//  SwiftSVGTests
//
//  Created by Kevin Meaney on 02/10/2015.
//  Copyright © 2015 No. All rights reserved.
//

import XCTest
import SwiftSVG

func makeURLFromNamedFile(namedFile: String, fileExtension: String) -> NSURL {
    let testBundle = NSBundle(forClass: SwiftSVGTests.self)
    let url = testBundle.URLForResource(namedFile, withExtension:fileExtension)!
    return url
}

class SwiftSVGTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let textDrawingURL = makeURLFromNamedFile("TextDrawing", fileExtension: "svg")
        var encoding = NSStringEncoding()
        guard let source = try? String(contentsOfURL: textDrawingURL, usedEncoding: &encoding),
            let xmlDocument = try? NSXMLDocument(XMLString: source, options: 0) else {
            XCTAssert(false, "Failed to get SVG string from file.")
            return
        }
        let processor = SVGProcessor()
        guard let svgDocument = try? processor.processXMLDocument(xmlDocument) else {
            XCTAssert(false, "Failed to create an svgDocument.")
            return
        }
    
        if let svgDocument = svgDocument {
            XCTAssert(svgDocument.children.count == 1, "TextDrawing should have 1 child.")
            
            svgDocument.printElements()
        }
        else {
            XCTAssert(false, "Failed to create an svgDocument.")
        }
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
