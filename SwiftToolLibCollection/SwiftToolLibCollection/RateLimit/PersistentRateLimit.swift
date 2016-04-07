//
//  PersistentRateLimit.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public class PersistentRateLimit: RateLimit {
    // MARK: - RateLimit
    public override class func clean() {
        super.clean()
        
        guard let fileURL = fileURL
            else {
                return
        }
        do {
            try NSFileManager.defaultManager().removeItemAtURL(fileURL)
        }
        catch { }
    }
    
    // MARK: - Private
    private static let fileURL: NSURL? = {
        let doucments = NSFileManager.defaultManager().URLsForDirectory(.DocumentationDirectory, inDomains: .UserDomainMask).last
        
        return doucments?.URLByAppendingPathComponent("SAMPersistentRateLimit.plist")
    }()
    
    override class func didChangeDictionary() {
        guard let fileURL = fileURL
            else {
                return
        }
        dispatch_async(queue) {
            let dictionary = self.dictionary as NSDictionary
            dictionary.writeToURL(fileURL, atomically: true)
        }
    }
}
