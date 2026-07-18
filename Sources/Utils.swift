//
//  Utils.swift
//  
//
//  Created by Brandon Wees on 7/6/24.
//

import Foundation
import SWXMLHash

public enum XMLParsingError: Error {
    case elementMissing
    case attributeMissing(named: String, on: SWXMLHash.XMLElement?)
    case childNotFound(named: String, at: String)
    case initialFunctionPathInvalid
    case enumCastFailed(enumType: String, stringValue: String)
    case invalidUUID(text: String)
    case nodeResolutionFailed(path: String)
    case noChildren(in: String)
    case failedToParseString
}

extension XMLAttribute {
    
    fileprivate func resolveXML(at pathStr: String, base: XMLIndexer, tree fullTree: XMLIndexer) throws -> (Int, XMLIndexer) {
        let path = pathStr.components(separatedBy: ".")
        var tree = base
        var foundIndex = -1
        
        for step in path {
            guard let (idx, nextTree) = try tree.children.enumerated().first(where: { (index, child) in
                guard let childElement = child.element else {
                    throw XMLParsingError.childNotFound(named: step, at: path.joined(separator: "."))
                }
                
                // if the childElement is a DMXChannel, we have to build its name manually
                // "The name of a DMX channel cannot be user-defined and must consist of a geometry
                // name and the attribute name of the first logical channel with separator "_"."
                if (childElement.name == "DMXChannel") {
                    guard let logicalChannel = try child.child(named: "LogicalChannel").element else {
                        throw XMLParsingError.childNotFound(named: "LogicalChannel", at: child.element?.text ?? "N/A")
                    }
                    
                    let channelName = try childElement.attribute(named: "Geometry").text + "_" + logicalChannel.attribute(named: "Attribute").text
                    
                    return channelName == step
                }
                
                // if there is a name field
                if let name = (try? childElement.attribute(named: "Name"))?.text,
                   name == step {
                    return true
                }
                
                // if there is a attribute field
                if let name = (try? childElement.attribute(named: "Attribute"))?.text,
                   name == step {
                    return true
                }
                
                // if there is a Type field and its a SubPhysicalUnit
                if (childElement.name == "SubPhysicalUnit"),
                   let name = (try? childElement.attribute(named: "Type"))?.text,
                   name == step {
                    return true
                }
                
                if (childElement.name == "ChannelFunction") {
                    let name = (try? childElement.attribute(named: "Attribute").text + " " + String(index+1))
                    if (name == step) { return true }
                }
                
                // otherwise we need to look for ChannelFunction for the name
                if let initialFunction = try? childElement.attribute(named: "InitialFunction").text {
                    let initialFunctionParts = initialFunction.components(separatedBy: ".")
                    guard initialFunctionParts.count >= 3 else {
                        throw XMLParsingError.initialFunctionPathInvalid
                    }
                                    
                    if (initialFunctionParts.first == step) { return true }
                }
                
                return false
            }) else {
                throw XMLParsingError.childNotFound(named: step, at: pathStr)
            }
                        
            tree = nextTree
            foundIndex = idx
        }
        
        return (foundIndex, tree)
    }
    
    func resolveNode<T: XMLDecodable>(base: XMLIndexer, tree fullTree: XMLIndexer) throws -> T {
        let pathStr = self.text
        
        let (_, foundTree) = try resolveXML(at: pathStr, base: base, tree: fullTree)
        
        return try T(xml: foundTree, tree: fullTree)
    }
    
    func resolveNode<T: XMLDecodableWithIndex>(base: XMLIndexer, tree fullTree: XMLIndexer) throws -> T {
        let pathStr = self.text
        
        let (idx, foundTree) = try resolveXML(at: pathStr, base: base, tree: fullTree)
        
        return try T(xml: foundTree, index: idx, tree: fullTree)
    }
    
    
}

extension XMLIndexer {
    func parseChildrenToArray<T: XMLDecodable>(tree fullTree: XMLIndexer) throws -> [T] {
        return try self.children.map { child in
            try child.parse(tree: fullTree)
        }
    }
    
    func parseChildrenToArray<T: XMLDecodableWithParent>(parent: XMLIndexer, tree fullTree: XMLIndexer) throws -> [T]  {
        return try self.children.map { child in
            try child.parse(parent: parent, tree: fullTree)
        }
    }
    
    func parseChildrenToArray<T: XMLDecodableWithIndex>(tree fullTree: XMLIndexer) throws -> [T] {
        return try self.children.enumerated().map { (index, child) in
            try child.parse(index: index, tree: fullTree)
        }
    }
    
    func parse<T: XMLDecodable>(tree fullTree: XMLIndexer) throws -> T  {
        return try T(xml: self, tree: fullTree)
    }
    
    func optionalParse<T: XMLDecodable>(tree fullTree: XMLIndexer) throws -> T? {
        guard self.element != nil else { return nil }
        
        return try self.parse(tree: fullTree)
    }
    
    func parse<T: XMLDecodableWithIndex>(index: Int, tree fullTree: XMLIndexer) throws -> T {
        return try T(xml: self, index: index, tree: fullTree)
    }
    
    func parse<T: XMLDecodableWithParent>(parent: XMLIndexer, tree fullTree: XMLIndexer) throws -> T {
        return try T(xml: self, parent: parent, tree: fullTree)
    }
    
    func child(named name: String) throws -> XMLIndexer {
        guard let child = self.children.first(where: { c in c.element?.name.lowercased() == name.lowercased() }) else {
            throw XMLParsingError.childNotFound(named: name, at: self.element?.text ?? "")
        }
        
        return child
    }
    
    func findChild(with attributeName: String, being match: String) throws -> XMLIndexer {
        guard let child = self.children.first(where: { c in
            c.element?.attribute(by: attributeName)?.text == match
        }) else {
            throw XMLParsingError.childNotFound(named: attributeName + " == " + match, at: self.element?.text ?? "")
        }

        return child
    }

    /// Resolve an optional single-name (`nametype`) reference by exact `Name` match; nil when
    /// the reference is absent or empty. Unlike `resolveNode`, it does NOT split on "." — GDTF
    /// names may legally contain a period (the nametype char range spans it).
    func resolveNamed<T: XMLDecodable>(_ ref: XMLAttribute?, tree fullTree: XMLIndexer) throws -> T? {
        guard let name = ref?.text, !name.isEmpty else { return nil }
        return try findChild(with: "Name", being: name).parse(tree: fullTree)
    }
    
    func firstChild() throws -> XMLIndexer {
        guard let firstChild = self.children.first else {
            throw XMLParsingError.noChildren(in: self.element?.text ?? "")
        }
        
        return firstChild
    }
}

extension XMLAttribute {
    var double: Double? {
        return Double(self.text)
    }
    
    var int: Int? {
        return Int(self.text)
    }

    var uuid: UUID {
        get throws {
            guard let uuid = UUID(uuidString: text) else {
                throw XMLParsingError.invalidUUID(text: text)
            }
            return uuid
        }
    }
    
    func toEnum<T: RawRepresentable>() throws -> T {
        guard let raw = self.text as? T.RawValue, let enumValue = T(rawValue: raw) else {
            throw XMLParsingError.enumCastFailed(enumType: String(describing: T.self), stringValue: self.text)
        }
        
        return enumValue
    }
}

extension SWXMLHash.XMLElement {
    func attribute(named name: String) throws -> XMLAttribute {
        guard let attr = self.attribute(by: name) else {
            throw XMLParsingError.attributeMissing(named: name, on: self)
        }
        
        return attr
    }
}

extension Double {
    func constrain(min: Double, max: Double) -> Double {
        if self > max {
            return max
        }
        
        if self < min {
            return min
        }
        
        return self
    }
}
