//
//  SwifterHttpServer.swift
//  SwifterServer
//
//  Created by Riven on 16/4/11.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public class SwifterHttpServer: SwifterHttpServerIO {
    public static let VERSION = "1.1.3"
    
    private let router = SwifterHttpRouter()
    
    public struct MethodRoute {
        public let method: String
        public let router: SwifterHttpRouter
        public subscript(path: String) -> (SwifterHttpRequest -> SwifterHttpResponse)? {
            set {
                router.register(method, path: path, handler: newValue)
            }
            get {
                return nil
            }
        }
    }
    
    public var DELETE, UPDATE, HEAD, POST, GET, PUT: MethodRoute
    public var delete, update, head, post, get, put: MethodRoute
    
    public override init() {
        self.DELETE = MethodRoute(method: "DELETE", router: router)
        self.UPDATE = MethodRoute(method: "UPDATE", router: router)
        self.HEAD = MethodRoute(method: "HEAD", router: router)
        self.POST = MethodRoute(method: "POST", router: router)
        self.GET = MethodRoute(method: "GET", router: router)
        self.PUT = MethodRoute(method: "UPDATE", router: router)
        
        self.delete = MethodRoute(method: "DELETE", router: router)
        self.update = MethodRoute(method: "UPDATE", router: router)
        self.head = MethodRoute(method: "HEAD", router: router)
        self.post = MethodRoute(method: "POST", router: router)
        self.get = MethodRoute(method: "GET", router: router)
        self.put = MethodRoute(method: "UPDATE", router: router)
    }
    
    public subscript(path: String) -> (SwifterHttpRequest -> SwifterHttpResponse)? {
        set {
            router.register(nil, path: path, handler: newValue)
        }
        
        get { return nil }
    }
    
    public var routes: [String] {
        return router.routes()
    }
    
    override public func dispath(method: String, path: String) -> ([String : String], SwifterHttpRequest -> SwifterHttpResponse) {
        if let result = router.route(method, path: path) {
            return result
        }
        return super.dispath(method, path: path)
    }
}