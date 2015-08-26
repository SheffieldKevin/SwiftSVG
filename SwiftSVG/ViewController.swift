//
//  ViewController.swift
//  SwiftSVGTestNT
//
//  Created by Jonathan Wight on 2/25/15.
//  Copyright (c) 2015 No. All rights reserved.
//

import Cocoa

import SwiftGraphics

class ViewController: NSViewController {

    @IBOutlet var svgView: SVGView!
    @IBOutlet var treeController: NSTreeController!
    var summaryViewController:SummaryViewController!
    @objc dynamic var root: [ObjectAdaptor]!
    @objc dynamic var selectionIndexPaths: [NSIndexPath]! {
        didSet {
            let selectedObjects = treeController.selectedObjects as! [ObjectAdaptor]
//            let selectedElements:[SVGElement] = selectedObjects.map() {
//                return $0.object as! SVGElement
//            }
//            self.selectedElements = NSMutableSet(array: selectedElements)
            svgView.needsDisplay = true
        }
    }

//    @objc dynamic var selectedElements:NSMutableSet = NSMutableSet()

    var svgDocument: SVGDocument! = nil {
        didSet {
            svgView?.svgDocument = svgDocument
            if let svgDocument = svgDocument {
                root = [ObjectAdaptor(object:svgDocument, template:treeNodeTemplate())]
            }
            summaryViewController.svgDocument = svgDocument
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
//            if self.selectedElements.contains(svgElement) {
            if false {

                if let transform = svgElement.transform {
                    CGContextConcatCTM(context, transform.asCGAffineTransform())
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
                case is SVGDocument:
                    return "Document"
                case is SVGGroup:
                    return "Group"
                case is SVGPath:
                    return "Path"
                default:
                    assert(false)
            }
        }
        return template
    }

    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        // TODO: Yeah this is shit

        summaryViewController = segue.destinationController as! SummaryViewController
    }

    @IBAction func flatten(sender:AnyObject?) {

        // TODO: Search for references to remove group

        // Don't modify tree as we're walking it - so keep a list of groups to flatten
        var parents:[SVGGroup] = []

        // Find group elements with exactly 1 child
        SVGElement.walker.walk(svgDocument) {
            (element:SVGElement, depth: Int) -> Void in
            if let group = element as? SVGGroup where group.children.count == 1 {
                parents.append(group)
            }
        }

        // Now process the found groups
        for parent in parents {

            let child = parent.children[0]

            // Concat the parent style with the child style
            let style = (parent.style ?? Style()) + (child.style ?? Style())
            if style.isEmpty == false {
                child.style = style
            }

            // Concat the parent transform with the child transform
            let transform = (parent.transform ?? IdentityTransform()) + (child.transform ?? IdentityTransform())
            if transform.isIdentity == false {
                child.transform = transform
            }

            // Replace the parent with the child
            if let grandParent = parent.parent {
                grandParent.replace(parent, with: child)
            }
        }

        // TODO: Total hack. Work out a better way to transmit state updates

//        root = [ObjectAdaptor(object:svgDocument, template:treeNodeTemplate())]
//        svgView.needsDisplay = true

        willChangeValueForKey("svgDocument")
        didChangeValueForKey("svgDocument")

        summaryViewController.deepThought()

    }
}
