//
//  Closeable.swift
//  PerfectLib
//
//  Created by Riven on 16/4/12.
//  Copyright © 2016年 Riven. All rights reserved.
//

public protocol Closeable {
    func close() -> Void
    func doWithClose(c: () -> ()) -> Void
}

extension Closeable {
    public func doWithClose(c: () -> ()) -> Void {
        defer { self.close() }
        
        c()
    }
}
