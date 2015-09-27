//
//  ViewController.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Cocoa

import SwiftGraphics
import SwiftSVG

class ViewController: NSViewController {

    weak dynamic var document: Document! = nil {
        didSet {
            source = document.source
        }
    }

    dynamic var source: String? = nil {
        didSet {
            do {
                try self.parse()
            }
            catch let error {
                print(error)
            }
            document.source = source
        }
    }

    var svgDocument: SVGDocument? = nil {
        didSet {
            svgView?.svgDocument = svgDocument
            if let svgDocument = svgDocument {
                root = [ObjectAdaptor(object: svgDocument, template: ViewController.treeNodeTemplate())]
            }
            else {
                root = nil
            }

            summaryViewController.svgDocument = svgDocument
        }
    }

    @IBOutlet var sourceView: NSTextView!
    @IBOutlet var svgView: SVGView!
    @IBOutlet var treeController: NSTreeController!

    dynamic var root: [ObjectAdaptor]!
    dynamic var selectionIndexPaths: [NSIndexPath]! {
        didSet {
            let selectedObjects = treeController.selectedObjects as! [ObjectAdaptor]
            let selectedElements: [SVGElement] = selectedObjects.map() {
                return $0.object as! SVGElement
            }
            self.selectedElements = Set <SVGElement> (selectedElements)
            svgView.needsDisplay = true
        }
    }

    var summaryViewController: SummaryViewController!

    var selectedElements: Set <SVGElement> = Set <SVGElement> ()

    override func viewDidLoad() {
        super.viewDidLoad()

        sourceView.font = NSFont(name: "Menlo", size: 12)

        svgView.elementSelected = {
            (svgElement: SVGElement) -> Void in
            self.treeController.setSelectionIndexPaths([svgElement.indexPath])
        }

        svgView.svgRenderer.callbacks.prerenderElement = {
            (svgElement: SVGElement, renderer: Renderer) -> Bool in
            if self.selectedElements.contains(svgElement) {
                renderer.pushGraphicsState()
                defer {
                    renderer.restoreGraphicsState()
                }

                if let transform = svgElement.transform {
                    renderer.concatCTM(transform.toCGAffineTransform())
                }

                let path = try self.svgView.svgRenderer.pathForElement(svgElement)
                // renderer.strokeColor = CGColor.greenColor()
                renderer.fillColor = CGColor.greenColor()
                renderer.addCGPath(path)
                renderer.fillPath()
                return false
            }

            return true
        }
    }

    func parse() throws {
        guard let source = source else {
            svgDocument = nil
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


    static func treeNodeTemplate() -> ObjectAdaptor.Template {
        var template = ObjectAdaptor.Template()
        template.childrenGetter = {
            (element) in
            guard let element = element as? SVGContainer else {
                return nil
            }
            return element.children
        }
        template.getters["id"] = {
            (element) in
            return (element as? SVGElement)?.id
        }
        template.getters["styled"] = {
            (element) in
            return (element as? SVGElement)?.style != nil ? true: false
        }
        template.getters["transformed"] = {
            (element) in
            return (element as? SVGElement)?.transform != nil ? true: false
        }
        template.getters["fillColor"] = {
            (element) in
            guard let cgColor = (element as? SVGElement)?.style?.fillColor else {
                return nil
            }
            return NSColor(CGColor: cgColor)
        }
        template.getters["strokeColor"] = {
            (element) in
            guard let cgColor = (element as? SVGElement)?.style?.strokeColor else {
                return nil
            }
            return NSColor(CGColor: cgColor)
        }
        template.getters["strokeWidth"] = {
            (element) in
            guard let lineWidth = (element as? SVGElement)?.style?.lineWidth else {
                return nil
            }
            return lineWidth
        }
        template.getters["name"] = {
            (element) in
            switch element {
                case is SVGDocument:
                    return "Document"
                case is SVGGroup:
                    return "Group"
                case is SVGPath:
                    return "Path"
                case is SVGRect:
                    return "Rect"
                case is SVGEllipse:
                    return "Ellipse"
                case is SVGCircle:
                    return "Circle"
                case is SVGPolygon:
                    return "Polygon"
                case is SVGPolyline:
                    return "Polyline"
                case is SVGLine:
                    return "Line"
                default:
                    preconditionFailure()
            }
        }
        return template
    }

    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        // TODO: Yeah this is shit

        summaryViewController = segue.destinationController as! SummaryViewController
    }

    @IBAction func flatten(sender: AnyObject?) {

        guard let svgDocument = svgDocument else {
            return
        }

        svgDocument.optimise()

        // TODO: Total hack. Should not need to rebuild entire world.

        root = [ObjectAdaptor(object: svgDocument, template: ViewController.treeNodeTemplate())]
        svgView.needsDisplay = true

        willChangeValueForKey("svgDocument")
        didChangeValueForKey("svgDocument")

        try! summaryViewController.deepThought()

    }

    @IBAction func export(sender: AnyObject?) {
        guard let svgDocument = svgDocument else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["public.json"]
        savePanel.beginSheetModalForWindow(self.svgView.window!, completionHandler: { result in
            guard result == NSModalResponseOK else {
                return
            }

            let renderer = MovingImagesRenderer()
            let svgRenderer = SVGRenderer()
            let _ = try? svgRenderer.renderDocument(svgDocument, renderer: renderer)
            let jsonObject = renderer.generateJSONDict()
            writeMovingImagesJSONObject(jsonObject, fileURL: savePanel.URL!)
        })
    }
    
    @IBAction func processFolder(sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "SVG Files"
        openPanel.prompt = "Select a folder containing SVG files to be processed"
        
        openPanel.beginWithCompletionHandler({
            result in
            guard result == NSFileHandlingPanelOKButton else {
                return
            }
            let folderURL = openPanel.URLs[0]
            // Need to find any svg files in the folder.
            let fileManager = NSFileManager.defaultManager()
            let fileList = try? fileManager.contentsOfDirectoryAtURL(folderURL,
                        includingPropertiesForKeys: nil,
                                           options: [])
            guard let files = fileList where files.count > 0 else {
                return
            }

            /*
            let svgFiles = files.filter() {
                fileURL in
                var stringValue:AnyObject? = nil
                if let _ = try? fileURL.getResourceValue(&stringValue, forKey: NSURLTypeIdentifierKey) {
                    if let uti = stringValue as? NSString {
                        if uti.isEqualToString("public.svg-image") {
                            return true
                        }
                    }
                }
                return false
            }
            */

            let svgFiles = files.filter() {
                fileURL in
                return fileURL.lastPathComponent!.hasSuffix(".svg")
            }

            guard svgFiles.count > 0 else {
                return
            }
            
            // OK we have more than one file, lets put up the dialog to ask where do we want to save the results
            let savePanel = NSOpenPanel()
            savePanel.canChooseDirectories = true
            savePanel.canChooseFiles = false
            savePanel.canCreateDirectories = true
            savePanel.allowsMultipleSelection = false
            savePanel.title = "MovingImages drawing files"
            savePanel.prompt = "Select a folder where you want to save the moving images files"
            savePanel.beginWithCompletionHandler({
                result in
                guard result == NSFileHandlingPanelOKButton else {
                    return
                }
                let destFolder = savePanel.URLs[0]
                
                dispatch_apply(svgFiles.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                    index in
                    let svgFileURL = svgFiles[index]
                    let svgFileName = svgFileURL.lastPathComponent!
                    let movingImagesFile = svgFileName.stringByReplacingOccurrencesOfString(".svg", withString: ".json")
                    let newFileURL = destFolder.URLByAppendingPathComponent(movingImagesFile)
                    var encoding = NSStringEncoding()
                    guard let source = try? String(contentsOfURL: svgFileURL, usedEncoding: &encoding) else {
                        return
                    }
                    guard let xmlDocument = try? NSXMLDocument(XMLString: source, options: 0) else {
                        return
                    }
                    
                    let processor = SVGProcessor()
                    guard let tempDocument = try? processor.processXMLDocument(xmlDocument) else {
                        return
                    }
                    guard let svgDocument = tempDocument else {
                        return
                    }

                    let renderer = MovingImagesRenderer()
                    let svgRenderer = SVGRenderer()
                    let _ = try? svgRenderer.renderDocument(svgDocument, renderer: renderer)
                    let jsonObject = renderer.generateJSONDict()
                    writeMovingImagesJSONObject(jsonObject, fileURL: newFileURL)
                })
            })
        })
    }
}
