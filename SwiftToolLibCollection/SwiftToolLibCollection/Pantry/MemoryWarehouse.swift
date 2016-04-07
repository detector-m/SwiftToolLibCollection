//
//  MemoryWarehouse.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public class MemoryWarehouse {
    required public init(key: String, inMemoryIdentifier: String) {
        self.key = key
        self.inMemoryIdentifier = inMemoryIdentifier
    }
    
    required public init(context: AnyObject, inMemoryIdentifier: String) {
        self.key = ""
        self.context = context
        self.inMemoryIdentifier = inMemoryIdentifier
    }
    
    var key: String
    var context: AnyObject?
    let inMemoryIdentifier: String
    
    static var globalCache: [String: [String: AnyObject]] = [: ]
}

extension MemoryWarehouse: Warehouseable {
    public func get<T : StorableDefaultType>(valueKey: String) -> T? {
        guard let dictionary = loadCache(), let result = dictionary[valueKey] as? T else {
            return nil
        }
        
        return result
    }
    
    public func get<T : StorableDefaultType>(valueKey: String) -> [T]? {
//        guard let dictionary = loadCache() as? Dictionary<String, AnyObject>,
//            let result = dictionary[valueKey] as? Array<AnyObject> else {
//                return nil
//        }
        guard let dictionary = loadCache() as? [String: AnyObject], let result = dictionary[valueKey] as? [AnyObject] else {
            return nil
        }
        
        var unpackedItems = [T]()
        for case let item as T in result {
            unpackedItems.append(item)
        }
        
        return unpackedItems
    }
    
    public func get<T : Storable>(valueKey: String) -> T? {
//        guard let dictionary = loadCache() as? Dictionary<String, AnyObject>,
//            let result = dictionary[valueKey] else {
//                return nil
//        }
        guard let dictionary = loadCache() as? [String: AnyObject], let result = dictionary[valueKey]
            else {
            return nil
        }
        let warehouse = MemoryWarehouse(context: result, inMemoryIdentifier: inMemoryIdentifier)
        return T(warehouse: warehouse)
    }
    
    public func get<T : Storable>(valueKey: String) -> [T]? {
//        guard let dictionary = loadCache() as? Dictionary<String, AnyObject>,
//            let result = dictionary[valueKey] as? Array<AnyObject> else {
//                return nil
//        }
        guard let dictionary = loadCache() as? [String: AnyObject], let result = dictionary[valueKey] as? [AnyObject] else {
            return nil
        }
        var unpackedItems = [T]()
        for case let item as [String: AnyObject] in result {
            let warehouse = MemoryWarehouse(context: item, inMemoryIdentifier: inMemoryIdentifier)
            if let item = T(warehouse: warehouse) {
                unpackedItems.append(item)
            }
        }

        return unpackedItems
    }
}

extension MemoryWarehouse: WarehouseCacheable {
    public func write(object: AnyObject, expires: StorageExpiry) {
        var storableDictionary = [String: AnyObject]()
        
        storableDictionary["expires"] = expires.toDate().timeIntervalSince1970
        storableDictionary["storage"] = object
        
        var memoryCache = MemoryWarehouse.globalCache[inMemoryIdentifier] ?? [String: AnyObject]()
        memoryCache[key] = storableDictionary
        MemoryWarehouse.globalCache[inMemoryIdentifier] = memoryCache
    }
    
    func removeCache() {
        MemoryWarehouse.globalCache.removeValueForKey(key)
    }
    
    func loadCache() -> AnyObject? {
        guard context == nil
            else {
                return context
        }
        
        if let memoryCache = MemoryWarehouse.globalCache[inMemoryIdentifier], let cacheItem = memoryCache[key], let item = cacheItem["storage"] {
            return item
        }
        
        return nil
    }
    
    func cacheExists() -> Bool {
        return true
    }
}