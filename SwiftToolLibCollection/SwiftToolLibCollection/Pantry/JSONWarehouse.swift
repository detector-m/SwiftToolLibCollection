//
//  JSONWarehouse.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public class JSONWarehouse: Warehouseable, WarehouseCacheable {
    // MARK: -
    var key: String
    var context: AnyObject?
    
    // MARK: - init
    public init(key: String) {
        self.key = key
    }
    
    public init(context: AnyObject) {
        self.key = ""
        self.context = context
    }
    
    // MARK: - Warehouseable
    public func get<T : StorableDefaultType>(valueKey: String) -> T? {
        guard let dictionary = loadCache(), let result = dictionary[valueKey] as? T
            else {
                return nil
        }
        
        return result
    }
    
    public func get<T : StorableDefaultType>(valueKey: String) -> [T]? {
        guard let dictionary = loadCache() as? Dictionary<String, AnyObject>, let result = dictionary[valueKey] as? Array<AnyObject> else {
            return nil
        }
        
        var unpackedItems = [T]()
        for case let item as T in result {
            unpackedItems.append(item)
        }
        
        return unpackedItems
    }
    
    public func get<T : Storable>(valueKey: String) -> T? {
        guard let dictionary = loadCache() as? Dictionary<String, AnyObject>, let result = dictionary[valueKey]
            else {
                return nil
        }
        let warehouse = JSONWarehouse(context: result)
        return T(warehouse: warehouse)
    }
    
    public func get<T : Storable>(valueKey: String) -> [T]? {
        guard let dictionary = loadCache() as? Dictionary<String, AnyObject>, let result = dictionary[valueKey] as? Array<AnyObject>
            else {
                return nil
        }
        var unpackedItems = [T]()
        for case let item as Dictionary<String, AnyObject> in result {
            let warehouse = JSONWarehouse(context: item)
            if let item = T(warehouse: warehouse) {
                unpackedItems.append(item)
            }
        }
        
        return unpackedItems
    }
    
    // MARK: - WarehouseCacheable
    func write(object: AnyObject, expires: StorageExpiry) {
        let cacheLocation = cacheFileURL()
        var storableDictionary = [String: AnyObject]()
        
        storableDictionary["expires"] = expires.toDate().timeIntervalSince1970
        storableDictionary["storage"] = object
        
        let _ = (storableDictionary as NSDictionary).writeToURL(cacheLocation, atomically: true)
    }
    
    func removeCache() {
        try! NSFileManager.defaultManager().removeItemAtURL(cacheFileURL())
    }
    
    func loadCache() -> AnyObject? {
        guard context == nil
            else {
                return context
        }
        let cacheLocation = cacheFileURL()
        if let metaDictionary = NSDictionary(contentsOfURL: cacheLocation), let cache = metaDictionary["storage"] {
            return cache
        }
        
        return nil
    }
    
    func cacheExists() -> Bool {
        guard NSFileManager.defaultManager().fileExistsAtPath(cacheFileURL().path!), let metaDictionary = NSDictionary(contentsOfURL: cacheFileURL())
            else {
                return false
        }
        guard let expires = metaDictionary["expires"] as? NSTimeInterval else {
            return true
        }
        
        let nowInterval = NSDate().timeIntervalSince1970
        if expires > nowInterval {
            return true
        }
        else {
            removeCache()
            return false
        }
    }
    
    // MARK: - Private Methods
    private func cacheFileURL() -> NSURL {
        let url = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).first!
        let writeDirectory = url.URLByAppendingPathComponent("com.thatthinginswift.pantry")
        let cacheLocation = writeDirectory.URLByAppendingPathComponent(self.key)
//        do {
//            try NSFileManager.defaultManager().createDirectoryAtURL(writeDirectory, withIntermediateDirectories: true, attributes: nil)
//        }
//        catch {}
        try! NSFileManager.defaultManager().createDirectoryAtURL(writeDirectory, withIntermediateDirectories: true, attributes: nil)
        
        return cacheLocation
    }
}