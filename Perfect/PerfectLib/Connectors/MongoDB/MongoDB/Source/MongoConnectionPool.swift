//
//  MongoConnectionPool.swift
//  MongoDB
//
//  Created by Riven on 16/4/28.
//  Copyright © 2016年 Riven. All rights reserved.
//

import libmongoc

// Allows connection pooling. This class is thread-safe.

public class MongoClientPool {
    var ptr: COpaquePointer
    
    public init(uri: String) {
        let uriPointer = mongoc_uri_new(uri)
        ptr = mongoc_client_pool_new(uriPointer)
    }
    deinit {
        if ptr != nil {
            mongoc_client_pool_destroy(ptr)
        }
    }
    
    // try to pop a client connection from the connection pool. returns nil if no client connection is currently queued for reuse.
    public func tryPopClient() -> MongoClient? {
        let clientPointer = mongoc_client_pool_try_pop(ptr)
        if clientPointer != nil {
            return MongoClient(pointer: mongoc_client_pool_pop(clientPointer))
        }
        return nil
    }
    
    // Pop a client connection from the connection pool.
    public func popClient() -> MongoClient {
        return MongoClient(pointer: mongoc_client_pool_pop(ptr))
    }
    
    // pushes back poped client connection
    public func pushClient(client: MongoClient) {
        mongoc_client_pool_push(ptr, client.ptr)
        client.ptr = nil
    }
    
    // Automatically pops a client, makes it available within the block and pushes it back.
    public func executeBlock(@noescape block: (client: MongoClient) -> Void) {
        let client = popClient()
        block(client: client)
        pushClient(client)
    }
}


