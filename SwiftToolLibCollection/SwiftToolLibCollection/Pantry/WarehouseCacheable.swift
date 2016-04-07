//
//  WarehouseCacheable.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

protocol WarehouseCacheable {
    func write(object: AnyObject, expires: StorageExpiry)
    func removeCache()
    func loadCache() -> AnyObject?
    func cacheExists() -> Bool
}
