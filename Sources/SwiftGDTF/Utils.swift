//
//  File.swift
//  
//
//  Created by Brandon Wees on 7/6/24.
//

import Foundation
import SWXMLHash

func resolveNode<T: XMLDecodable>(path pathStr: String?, base: XMLIndexer, tree fullTree: XMLIndexer) -> T? {
    guard let pathStr else { return nil }
    
    let path = pathStr.components(separatedBy: ".")
    var tree = base
    
    for step in path {
        tree = tree.children.first(where: { child in
            if let name = child.element!.attribute(by: "Name")?.text {
                return name == step
            }
            
            return false
        })!
    }
    
    return T(xml: tree, tree: fullTree)
}

extension XMLIndexer {
    func parseChildrenToArray<T: XMLDecodable>(tree fullTree: XMLIndexer) -> [T] {
        return self.children.map { child in
            child.parse(tree: fullTree)
        }
    }
    
    func parseChildrenToArray<T: XMLDecodableWithParent>(parent: XMLIndexer, tree fullTree: XMLIndexer) -> [T] {
        return self.children.map { child in
            child.parse(parent: parent, tree: fullTree)
        }
    }
    
    func parse<T: XMLDecodable>(tree fullTree: XMLIndexer) -> T {
        return T(xml: self, tree: fullTree)
    }
    
    func parse<T: XMLDecodableWithParent>(parent: XMLIndexer, tree fullTree: XMLIndexer) -> T {
        return T(xml: self, parent: parent, tree: fullTree)
    }
}

extension XMLAttribute {
    var float: Float? {
        return Float(self.text)
    }
    
    var int: Int? {
        return Int(self.text)
    }
    
    func toEnum<T: RawRepresentable>() -> T? {
        return T(rawValue: self.text as! T.RawValue)
    }
}
