//
//  RateLimit.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

/*
    RateLimit.execute(name: "Example", limit: 1) {
    }
*/
public class RateLimit {
    public class func execute(name name: String, limit: NSTimeInterval, @noescape block: Void -> ()) -> Bool {
        if sholudExecute(name: name, limit: limit) {
            block()
            return true
        }
        
        return false
    }
    
    public class func reset(name name: String) {
        dispatch_sync(queue) {
            dictionary.removeValueForKey(name)
        }
    }
    
    public class func clean() {
        dispatch_sync(queue) {
            dictionary.removeAll()
        }
    }
    
    // MARK: - Private
    static let queue: dispatch_queue_t = {
        let _queue = dispatch_queue_create("com.riven.ratelimit", DISPATCH_QUEUE_SERIAL)
        return _queue
    }()
    
    static var dictionary = [String: NSDate]() {
        didSet {
            didChangeDictionary()
        }
    }
    
    class func didChangeDictionary() {
        // Do nothing
    }
    
    private static func sholudExecute(name name: String, limit: NSTimeInterval) -> Bool {
        var should = false
        dispatch_sync(queue) {
            if let lastExecutedAt = dictionary[name] {
                let timeInterval = lastExecutedAt.timeIntervalSinceNow
                
                should = !(timeInterval < 0 && abs(timeInterval) < limit)
            }
            else {
                should = true
            }
            
            // Record execution
            dictionary[name] = NSDate()
        }
        
        return should
    }
}
