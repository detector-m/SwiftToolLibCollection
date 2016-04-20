//
//  Bytes.swift
//  PerfectLib
//
//  Created by Riven on 16/4/12.
//  Copyright © 2016年 Riven. All rights reserved.
//

public class Bytes {
    /// The position from which new export operations begin.
    public var position = 0
    // The underlying UInt8 array
    public var data: [UInt8]
    
    // Indicates the number of bytes which may be successfully exported
    public var availableExportBytes: Int {
        return self.data.count - self.position
    }
    
    // Create an empty Bytes object
    public init(existingBytes: [UInt8]) {
        self.data = existingBytes
    }
    
    public init(initialSize: Int) {
        self.data = [UInt8](count: initialSize, repeatedValue: 0)
    }
    
    // MARK: - Import
    // imports one UInt8 value appending it to the end of the array
    public func import8Bits(byte: UInt8) -> Bytes {
        data.append(byte)
        return self
    }
    public func import16Bits(short: UInt16) -> Bytes {
        data.append(UInt8(short & 0xff))
        data.append(UInt8((short >> 8) & 0xff))
        return self
    }
    public func import32Bits(int: UInt32) -> Bytes {
        data.append(UInt8(int & 0xff))
        data.append(UInt8((int >> 8) & 0xff))
        data.append(UInt8((int >> 16) & 0xff))
        data.append(UInt8((int >> 24) & 0xff))
        
        return self
    }
    public func import64Bits(int: UInt64) -> Bytes {
        data.append(UInt8(int & 0xff))
        data.append(UInt8((int >> 8) & 0xff))
        data.append(UInt8((int >> 16) & 0xff))
        data.append(UInt8((int >> 24) & 0xff))
        data.append(UInt8((int >> 32) & 0xff))
        data.append(UInt8((int >> 40) & 0xff))
        data.append(UInt8((int >> 48) & 0xff))
        data.append(UInt8((int >> 56) & 0xff))
        
        return self
    }
    
    // Imports an array of UInt8 
    public func importBytes(bytes: [UInt8]) -> Bytes {
        data.appendContentsOf(bytes)
        return self
    }
    
    public func importBytes(bytes: Bytes) -> Bytes {
        data.appendContentsOf(bytes.data)
        return self
    }
    
    public func importBytes(bytes: ArraySlice<UInt8>) -> Bytes {
        data.appendContentsOf(bytes)
        return self
    }
    
    // MARK: - Export
    public func export8Bits() -> UInt8 {
        let result = data[position]
        position += 1
        return result
    }
    
    public func export16Bits() -> UInt16 {
        let one = UInt16(data[position])
        position += 1
        let two = UInt16(data[position])
        position += 1
        
        return (two << 8) + one
    }
    
    public func export32Bits() -> UInt32 {
        let one = UInt32(data[position])
        position += 1
        let two = UInt32(data[position])
        position += 1
        let three = UInt32(data[position])
        position += 1
        let four = UInt32(data[position])
        position += 1

        return (four << 24) + (three << 16) + (two << 8) + one
    }
    
    public func export64Bits() -> UInt64 {
        let one = UInt64(data[position])
        position += 1
        let two = UInt64(data[position])
        position += 1
        let three = UInt64(data[position])
        position += 1
        let four = UInt64(data[position])
        position += 1
        
        let five = UInt64(data[position])
        position += 1
        let six = UInt64(data[position])
        position += 1
        let seven = UInt64(data[position])
        position += 1
        let eight = UInt64(data[position])
        position += 1
        
        return (eight << 56) + (seven << 48) + (six << 40) + (five << 32) + (four << 24) + (three << 16) + (two << 8) + one
    }
    
    public func exportBytes(count: Int) -> [UInt8] {
        var sub = [UInt8]()
        let end = self.position + count
        while self.position < end {
            sub.append(self.data[self.position])
            self.position += 1
        }
        
        return sub
    }
}
