//
//  LogManager.swift
//  PerfectLib
//
//  Created by Riven on 16/4/14.
//  Copyright © 2016年 Riven. All rights reserved.
//

public class LogManager {
    static func logMessage(msg: String) {
        print(msg)
    }
    static func logMessageCode(msg: String, code: Int) {
        print("\(msg) \(code)")
    }
}