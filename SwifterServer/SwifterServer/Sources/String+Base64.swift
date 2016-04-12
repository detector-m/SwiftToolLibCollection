//
//  String+Base64.swift
//  SwifterServer
//
//  Created by Riven on 16/4/8.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

extension String {
    private static let CODES = [UInt8]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".utf8)
    public static func toBase64(data: [UInt8]) -> String {
        // based on : https://en.wikipedia.org/wiki/Base64#Sample_Implementation_in_Java
        
        var result: [UInt8] = []
        var tmp: UInt8
        for index in 0.stride(to: data.count, by: 3) {
            let byte = data[index]
            tmp = (byte & 0xfc) >> 2
            result.append(CODES[Int(tmp)])
            tmp = (byte & 0x03) << 4
            if index + 1 < data.count {
                tmp |= (data[index + 1] & 0xf0) >> 4
                result.append(CODES[Int(tmp)])
                tmp = (data[index + 1] & 0x0f) << 2
                if index + 2 < data.count {
                    tmp |= (data[index + 2] & 0xc0) >> 6
                    result.append(CODES[Int(tmp)])
                    tmp = data[index + 2] & 0x3f
                    result.append(CODES[Int(tmp)])
                }
                else {
                    result.append(CODES[Int(tmp)])
                    result.appendContentsOf([UInt8]("=".utf8))
                }
            }
            else {
                result.append(CODES[Int(tmp)])
                result.appendContentsOf([UInt8]("==".utf8))
            }
        }
        
        return String.fromUInt8(result)
    }
}