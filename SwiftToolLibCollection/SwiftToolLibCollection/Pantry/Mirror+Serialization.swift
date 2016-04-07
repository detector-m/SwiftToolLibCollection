//
//  Mirror+Serialization.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

extension Mirror {
    // MARK: - Dictionary representation
    // Returns the dictionary representation of the current `Mirror`
    // _Adapted from [@IanKeen] (https://gist.github.com/IanKeen/3a6c3b9a42aaf9fea982)_
    
    func toDictionary() -> [String: AnyObject] {
        let output = self.children.reduce([:]) {
            (result: [String: AnyObject], child) in
            guard let key = child.label
                else {
                    return result
            }
            var actualValue = child.value
            var childMirror = Mirror(reflecting: child.value)
            if let style = childMirror.displayStyle where style == .Optional && childMirror.children.count > 0 {
                actualValue = childMirror.children.first!.value
                childMirror = Mirror(reflecting: actualValue)
            }
            
            if let style = childMirror.displayStyle where style == .Collection {
                // collections need to be unwrapped, children tested and to dictionary called on each
                let converted: [AnyObject] = childMirror.children.filter {
                    $0.value is Storable || $0.value is AnyObject
                    }.map {
                        collectionChild in
                        if let convertable = collectionChild.value as? Storable {
                            return convertable.toDictionary()
                        }
                        else {
                            return collectionChild.value as! AnyObject
                        }
                }
                
                return combine(result, addition: [key: converted])
            }
            else {
                // non-collection types, toDictionary or just cast default types
                if let value = actualValue as? Storable {
                    return combine(result, addition: [key: value.toDictionary()])
                }
                else if let value = actualValue as? AnyObject {
                    return combine(result, addition: [key: value])
                }
                else {
                    // throw an error? not a type we support
                }
            }
            
            return result
        }
        
        if let superclassMirror = self.superclassMirror() {
            return combine(output, addition: superclassMirror.toDictionary())
        }
        
        return output
    }
    
    // Convenience for combining dictionaries
    private func combine(from: [String: AnyObject], addition: [String: AnyObject]) -> [String: AnyObject] {
        var result = [String: AnyObject]()
        [from, addition].forEach {
            dict in
            dict.forEach {
                result[$0.0] = $0.1
            }
        }
        
        return result
    }
}
