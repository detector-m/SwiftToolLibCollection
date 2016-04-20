//
//  PerfectLibTests.swift
//  PerfectLibTests
//
//  Created by Riven on 16/4/12.
//  Copyright © 2016年 Riven. All rights reserved.
//

import XCTest
@testable import PerfectLib

class PerfectLibTests: XCTestCase {
    
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
        
        do {
            try commitError()
        } catch {
            print("tttt")
            print(error)
        }
        print("ssssss")
        
    }
    
    enum Error: ErrorType {
        case Error(NSError)
    }
    
    @noreturn
    func commitError(s: String = "aa") throws {
        throw NSError(domain: "adef", code: Int(20), userInfo: nil)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
