//
//  ViewController.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet var svgView: SVGView!
    @IBOutlet var treeController: NSTreeController!
    @objc dynamic var root: [ObjectAdaptor]!
    @objc dynamic var selectionIndexPaths: [NSIndexPath]! {
        didSet {
            let selectedObjects = treeController.selectedObjects as! [ObjectAdaptor]
            let selectedElements:[SVGElement] = selectedObjects.map() {
                return $0.object as! SVGElement
            }
            self.selectedElements = Set <SVGElement> (selectedElements)
            svgView.needsDisplay = true
        }
    }

    var selectedElements:Set <SVGElement> = Set <SVGElement> ()

    var svgDocument: SVGDocument! = nil {
        didSet {
            svgView?.svgDocument = svgDocument
            if let svgDocument = svgDocument {
                root = [ObjectAdaptor(object:svgDocument, template:treeNodeTemplate())]
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        svgView.elementSelected = {
            (svgElement:SVGElement) -> Void in
            self.treeController.setSelectionIndexPaths([svgElement.indexPath])

        }

        svgView.renderer.callbacks.prerenderElement = {
            (svgElement:SVGElement, context:CGContext) -> Bool in
            if self.selectedElements.contains(svgElement) {

                if let transform = svgElement.transform {
                    CGContextConcatCTM(context, transform)
                }

                let path = self.svgView.renderer.pathForElement(svgElement)
                context.strokeColor = CGColor.greenColor()
                context.fillColor = CGColor.greenColor()
                CGContextAddPath(context, path)
                CGContextFillPath(context)
                return false
            }

            return true
        }
    }

    func treeNodeTemplate() -> ObjectAdaptor.Template {
        var template = ObjectAdaptor.Template()
        template.childrenGetter = {
            (element:AnyObject) -> [AnyObject] in
            if let document = element as? SVGDocument {
                return document.children
            }
            else if let group = element as? SVGGroup {
                return group.children
            }
            else {
                return []
            }
        }
        template.getters["id"] = {
            return ($0 as? SVGElement)?.id
        }
        template.getters["styled"] = {
            return ($0 as? SVGElement)?.style != nil ? true : false
        }
        template.getters["transformed"] = {
            return ($0 as? SVGElement)?.transform != nil ? true : false
        }
        template.getters["fillColor"] = {
            if let cgColor = ($0 as? SVGElement)?.style?.fillColor {
                return NSColor(CGColor: cgColor)
            }
            else {
                return nil
            }
        }
        template.getters["strokeColor"] = {
            if let cgColor = ($0 as? SVGElement)?.style?.strokeColor {
                return NSColor(CGColor: cgColor)
            }
            else {
                return nil
            }
        }
        template.getters["strokeWidth"] = {
            if let lineWidth = ($0 as? SVGElement)?.style?.lineWidth {
                return lineWidth
            }
            else {
                return nil
            }
        }
        template.getters["name"] = {
            switch $0 {
                case let document as SVGDocument:
                    return "Document"
                case let group as SVGGroup:
                    return "Group"
                case let path as SVGPath:
                    return "Path"
                default:
                    assert(false)
            }
        }
        return template
    }
}
