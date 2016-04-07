//
//  Warehousable.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public protocol  Warehouseable: class {
    /*
        Retrieve a `StorableDefaultType` for a given key
    
    */
    func get<T: StorableDefaultType>(valueKey: String) -> T?
    func get<T: StorableDefaultType>(valueKey: String) -> [T]?
    
    func get<T: Storable>(valueKey: String) -> T?
    func get<T: Storable>(valueKey: String) -> [T]?
}