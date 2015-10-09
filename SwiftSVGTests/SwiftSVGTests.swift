//
//  SwiftSVGTests.swift
//  SwiftSVGTests
//
//  Created by Kevin Meaney on 02/10/2015.
//  Copyright © 2015 No. All rights reserved.
//

import XCTest
import SwiftSVG

public enum TestError: ErrorType {
    case invalidFilePath
    case noContentInFile(String)
    case invalidXML
}

func makeURLFromNamedFile(namedFile: String, fileExtension: String) throws -> NSURL {
    let testBundle = NSBundle(forClass: SwiftSVGTests.self)
    guard let url = testBundle.URLForResource(namedFile, withExtension:fileExtension) else {
        throw TestError.invalidFilePath
    }
    
    return url
}

func svgSourceFromNamedFile(namedFile: String) throws -> String {
    let textDrawingURL = try makeURLFromNamedFile(namedFile, fileExtension: "svg")
    var encoding = NSStringEncoding()
    guard let source = try? String(contentsOfURL: textDrawingURL, usedEncoding: &encoding) else {
        throw TestError.noContentInFile(textDrawingURL.path!)
    }
    return source
}

func xmlDocumentFromNamedSVGFile(namedFile: String) throws -> NSXMLDocument {
    let source = try svgSourceFromNamedFile(namedFile)
    guard let xmlDocument = try? NSXMLDocument(XMLString: source, options: 0) else {
        throw TestError.invalidXML
    }
    return xmlDocument
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
    
    func testSimpleText() {
        let optionalSVGDocument: SVGDocument?
        do {
            let xmlDocument = try xmlDocumentFromNamedSVGFile("TextDrawing")
            let processor = SVGProcessor()
            optionalSVGDocument = try processor.processXMLDocument(xmlDocument)
        }
        catch let error {
            print(error)
            return
        }

        guard let svgDocument = optionalSVGDocument else {
            XCTAssert(false, "optionalSVGDocument should not be .None")
            return
        }
        
        XCTAssert(svgDocument.id == "Layer_1", "The document should have id Layer_1")
        XCTAssert(svgDocument.children.count == 1, "TextDrawing should have 1 child.")
        XCTAssert(svgDocument.children[0] is SVGSimpleText, "Only document child element should be a SVGSimpleText")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
