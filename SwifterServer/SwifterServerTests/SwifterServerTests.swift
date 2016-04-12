//
//  SwifterServerTests.swift
//  SwifterServerTests
//
//  Created by Riven on 16/4/8.
//  Copyright © 2016年 Riven. All rights reserved.
//

import XCTest
@testable import SwifterServer

class SwifterServerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let string: String = "abcde"
        let c = string.substringWithRange(Range(start: string.startIndex, end: string.endIndex.predecessor()))
        print(c)
        
//        let CODES = [UInt8]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".utf8)

    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
