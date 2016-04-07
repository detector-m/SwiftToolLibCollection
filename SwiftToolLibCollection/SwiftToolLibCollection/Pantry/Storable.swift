//
//  Storable.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public protocol Storable {
    // MARK: - 
    init?(warehouse: Warehouseable)

    // Dictionary representation
    // Returns the dictioanry representation of the current struct
    func toDictionary() -> [String: AnyObject]
}

public extension Storable {
    func toDictionary() -> [String: AnyObject] {
        return Mirror(reflecting: self).toDictionary()
    }
}

// MARK: - Storage expiry
public enum StorageExpiry {
    case Never
    case Seconds(NSTimeInterval)
    case Date(NSDate)
    
    func toDate() -> NSDate {
        switch self {
//        case Never:
        case .Never:
            return NSDate.distantFuture()
        case .Seconds(let timeInterval):
            return NSDate(timeIntervalSinceReferenceDate: timeInterval)
        case .Date(let date):
            return date
        }
    }
}

// MARK: default types that are supported
/*
    Default storable types
*/
public protocol StorableDefaultType {}
extension Bool: StorableDefaultType {}
extension String: StorableDefaultType {}
extension Int: StorableDefaultType {}
extension Float: StorableDefaultType {}
extension Double: StorableDefaultType {}
extension NSDate: StorableDefaultType {}

// MARK: Enums With Raw Values
public protocol StorableRawEnum: Storable {
//    typealias StorableRawType: StorableDefaultType
    typealias StorableRawType = StorableDefaultType
    
    // Provided automatically for enum's that have a raw value
    var rawValue: StorableRawType { get }
    init?(rawValue: StorableRawType)
}

public extension StorableRawEnum {
//    init?(warehouse: Warehouseable) {
//        if let value: StorableRawType = warehouse.get()
//    }
    
    func toDictionary() -> [String : AnyObject] {
        if let value = rawValue as? AnyObject {
            return ["rawValue": value]
        }
        
        return [: ]
    }
}

