//
//  MongoClient.swift
//  MongoDB
//
//  Created by Riven on 16/4/28.
//  Copyright © 2016年 Riven. All rights reserved.
//

import libmongoc

public enum MongoResult {
    case Success
    case Error(UInt32, UInt32, String)
    case ReplyDoc(BSON)
    case ReplyInt(Int)
    case ReplyCollection(MongoCollection)
    
    static func fromError(error: bson_error_t) -> MongoResult {
        var vError = error
        let message = withUnsafePointer(&vError.message) {
                String.fromCString(UnsafePointer($0))!
            }
        
        return .Error(error.domain, error.code, message)
    }
}

public enum MongoClientError: ErrorType {
    case InitError(String)
}

public class MongoClient {
    var ptr: COpaquePointer
    
    public typealias Result = MongoResult
    public init(uri: String) throws {
        self.ptr = mongoc_client_new(uri)
        if ptr == nil {
            throw MongoClientError.InitError("Could not parse URI '\(uri)'")
        }
    }
    
    init(pointer: COpaquePointer) {
        ptr = pointer
    }
    deinit {
        close()
    }
    public func close() {
        if self.ptr != nil {
            mongoc_client_destroy(self.ptr)
            self.ptr = nil
        }
    }
}