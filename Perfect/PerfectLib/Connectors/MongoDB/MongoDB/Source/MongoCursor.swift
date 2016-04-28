//
//  MongoCursor.swift
//  MongoDB
//
//  Created by Riven on 16/4/28.
//  Copyright © 2016年 Riven. All rights reserved.
//

import libmongoc

public class MongoCursor {
    var ptr: COpaquePointer
    
    init(rawPtr: COpaquePointer) {
        self.ptr = rawPtr
    }
    
    deinit {
        close()
    }
    public func close() {
        if self.ptr != nil {
            mongoc_cursor_destroy(self.ptr)
            self.ptr = nil
        }
    }
    
    public func next() -> BSON? {
        var bson = UnsafePointer<bson_t>(nil)
        if mongoc_cursor_next(self.ptr, &bson) {
            return NoDestroyBSON(rawBson: UnsafeMutablePointer<bson_t>(bson))
        }
        return nil
    }
}
