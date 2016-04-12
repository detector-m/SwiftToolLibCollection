//
//  SwifterHttpRouter.swift
//  SwifterServer
//
//  Created by Riven on 16/4/11.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public class SwifterHttpRouter {
    private class Node {
        var nodes = [String: Node]()
        var handler: (SwifterHttpRequest -> SwifterHttpResponse)? = nil
    }
    
    private var rootNode = Node()
    public func routes() -> [String] {
        var routes = [String]()
        for (_, child) in rootNode.nodes {
            routes.appendContentsOf(routesForNode(child))
        }
        return routes
    }
    private func routesForNode(node: Node, prefix: String = "") -> [String] {
        var result = [String]()
        if let _ = node.handler {
            result.append(prefix)
        }
        for (key, child) in node.nodes {
            result.appendContentsOf(routesForNode(child, prefix: prefix + "/" + key));
        }
        return result
    }
    
    public func register(method: String?, path: String, handler: (SwifterHttpRequest -> SwifterHttpResponse)?) {
        var pathSegments = stripQuery(path).split("/")
        if let method = method {
            pathSegments.insert(method, atIndex: 0)
        }
        else {
            pathSegments.insert("*", atIndex: 0)
        }
        var pathSegmentsGenerator = pathSegments.generate()
        inflate(&rootNode, generator: &pathSegmentsGenerator).handler = handler
    }
    
    public func route(method: String?, path: String) -> ([String: String], SwifterHttpRequest -> SwifterHttpResponse)? {
        if let method = method {
            let pathSegments = (method + "/" + stripQuery(path)).split("/")
            var pathSegmentsGenerator = pathSegments.generate()
            var params = [String: String]()
            if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
                return (params, handler)
            }
        }
        let pathSegments = ("*/" + stripQuery(path)).split("/")
        var pathSegmentsGenerator = pathSegments.generate()
        var params = [String: String]()
        if let handler = findHandler(&rootNode, params: &params, generator: &pathSegmentsGenerator) {
            return (params, handler)
        }
        
        return nil
    }
    
    private func inflate(inout node: Node, inout generator: IndexingGenerator<[String]>) -> Node {
        if let pathSegment = generator.next() {
            if let _ = node.nodes[pathSegment] {
                return inflate(&node.nodes[pathSegment]!, generator: &generator)
            }
            var nextNode = Node()
            node.nodes[pathSegment] = nextNode
            return inflate(&nextNode, generator: &generator)
        }
        
        return node
    }
    
    private func findHandler(inout node: Node, inout params: [String: String], inout generator: IndexingGenerator<[String]>) -> (SwifterHttpRequest -> SwifterHttpResponse)? {
        guard let pathToken = generator.next()
            else {
                return node.handler
        }
        let variableNodes = node.nodes.filter {
            $0.0.characters.first == ":"
        }
        if let variableNode = variableNodes.first {
            if variableNode.1.nodes.count == 0 {
                // if it is the last element of the pattern and it is a variable, stop the search and append a tail as a value for the variable
                let tail = generator.joinWithSeparator("/")
                if tail.utf8.count > 0 {
                    params[variableNode.0] = pathToken + "/" + tail
                }
                else {
                    params[variableNode.0] = pathToken
                }
                return variableNode.1.handler
            }
            params[variableNode.0] = pathToken
            return findHandler(&node.nodes[variableNode.0]!, params: &params, generator: &generator)
        }
        if let _ = node.nodes[pathToken] {
            return findHandler(&node.nodes[pathToken]!, params: &params, generator: &generator)
        }
        if let _ = node.nodes["*"] {
            return findHandler(&node.nodes["*"]!, params: &params, generator: &generator)
        }
        
        return nil
    }
    
    private func stripQuery(path: String) -> String {
        if let path = path.split("?").first {
            return path
        }
        
        return path
    }
}
