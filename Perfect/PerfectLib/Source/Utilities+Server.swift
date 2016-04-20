//
//  Utilities+Server.swift
//  PerfectLib
//
//  Created by Riven on 16/4/15.
//  Copyright © 2016年 Riven. All rights reserved.
//

extension UnicodeScalar {
    public func isWhiteSpace() -> Bool {
        return ICU.isWhiteSpace(self)
    }
    public func isDigit() -> Bool {
        return ICU.isDigit(self)
    }
    public func isAlphaNum() -> Bool {
        return ICU.isAlphaNum(self)
    }
    public func isHexDigit() -> Bool {
        return ICU.isHexDigit(self)
    }
}
