//
//  ExcuteDuration.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/7.
//  Copyright © 2016年 Riven. All rights reserved.
//

/*
Duration.measure("Tough Math", block: yourToughMathStuff)
In all cases (by default) you will get the output (assuming it took 243 milliseconds)

Tough Math took: 243ms
If measurements are nested, they will be appropriately indented in the output, for example if yourToughMath() made a measurement of part of its code you would see

Measuring Tough Math:
Part 1 took: 100ms
Part 2 took: 143ms
Tough Math took: 243ms
Understanding Performance Deviations

In order to better understand how your code is impacted by other things the system is doing you can get average times and standard deviations for block based measurements by supplying a number of iterations for the block, so

Duration.measure("Tough Math", iterations: 10, forBlock:myToughMath)
Would run the block 10 times, taking and reporting the 10 individual measurements and then the average time taken for the block, together with the standard deviation

Measuring Tough Math
Iteration 1 took: 243ms
Iteration 2 took: 242ms
...
Iteration 10 took: 243ms
Tough Math Average: 243ms
Tough Math STD Dev.: 1ms
Stopping Report Generation

Because you may want to stop reporting of measurements in release builds, you can set the logStyle variable in order to control the logging behavior

Duration.logStyle = .None
Will disable measurement logging. In the future I will extend this library to support logging to a data-structure for subsequent analysis, but at this point there are two valid values .None and .Print

If you are using Duration within a Package of your own that you are distributing, rather than just over-writing the log style, you can push your desired style, then pop it to restore it to what a consuming package would want. For example

public func myMethod(){
//Because this is a release of your package
//don't log measurements
pushLogStyle(.None)

// Do stuff that is instrumented

//Restore the logging style to whatever it was
//before
popLogStyle()
}
*/

import Foundation


public enum MeasurementLogStyle {
    case None
    case Print
}

public class ExcuteDuration {
    public typealias MeasuredBlock = () -> ()

    public static func push(logStyle: MeasurementLogStyle) {
        logStyleStack.append(self.logStyle)
        self.logStyle = logStyle
    }
    
    public static func pop() {
        logStyle = logStyleStack.removeLast()
    }
    
    /// ensures that if any parent measurement boundaries have not yet resulted
    // in output that their headers are displayed
    private static func reportContaining() {
        if logStyle != .None && depth > 0 {
            if logStyle == .Print {
                for stackPointer in 0..<timingStack.count {
                    let containingMeasurement = timingStack[stackPointer]
                    
                    if !containingMeasurement.reported {
                        print(String(count: stackPointer, repeatedValue: "\t" as Character) + "Measuring \(containingMeasurement):")
                        
                        timingStack[stackPointer] = (containingMeasurement.startTime, containingMeasurement.name, true)
                    }
                }
            }
        }
    }
    
    public static func startMeasurement(name: String) {
        if logStyle == .None {
            return
        }
        
        reportContaining()
        timingStack.append((now, name, false))
        
        depth++
    }
    
    public static func stopMeasurement() -> Double {
        if logStyle == .None {
            return 0.0
        }
        
        return stopMeasurement(nil)
    }
    
    public static func stopMeasurement(executionDetails: String?) -> Double {
        if logStyle == .None {
            return 0.0
        }
        
        let endTime = now
        precondition(depth > 0, "Attempt to stop a measurement when none has been started")
        let beginning = timingStack.removeLast()
        depth -= 1
        
        let took = endTime - beginning.startTime
        
        print("\(depthIndent)\(beginning.name) took: \(took.milliSeconds)" + (executionDetails == nil ? "" : "(\(executionDetails!))"))
        
        return took
    }
    
    public static func log(message: String, includeTimeStamp: Bool = false) {
//        if logStyle == .None {
//            return
//        }
        guard logStyle != .None
            else {
            return
        }
        reportContaining()
        
        if includeTimeStamp {
            let currentTime = now
            let timeStamp = currentTime - timingStack[timingStack.count - 1].startTime
            return print("\(depthIndent)\(message)  \(timeStamp.milliSeconds)ms")
        }
        else {
            return print("\(depthIndent)\(message)")
        }
    }
    
    public static func measure(name: String, block: MeasuredBlock) -> Double {
        if logStyle == .None {
            block()
            return 0
        }
        
        startMeasurement(name)
        block()
        return stopMeasurement()
    }
    
    public static func measure(name: String, iterations: Int = 10, forBlock block: MeasuredBlock) -> Double {
        guard logStyle != .None
            else {
                return 0
        }
        
        precondition(iterations > 0, "Iterations must be a positive integer")
        var total: Double = 0
        var samples = [Double]()
        
        print("\(depthIndent)Measuring \(name)")
        
        for i in 0..<iterations {
            let took = measure("Iteration \(i+1)", block: block)
            samples.append(took)
            total += took
        }
        
        let mean = total / Double(iterations)
        
        var deviation = 0.0
        for result in samples {
            let difference = result - mean
            deviation += difference * difference
        }
        let variance = deviation / Double(iterations)
        
        print("\(depthIndent)\(name) Average", mean.milliSeconds)
        print("\(depthIndent)\(name) STD Dev.", variance.milliSeconds)
        return mean
    }
    
    private static var depth = 0
    private static var depthIndent: String {
        return String(count: depth, repeatedValue: "\t" as Character)
    }
    private static var now: Double {
            return NSDate().timeIntervalSinceReferenceDate
    }
    
    private static var timingStack = [(startTime: Double, name: String, reported: Bool)]()
    private static var logStyleStack = [MeasurementLogStyle]()
    private static var logStyle = MeasurementLogStyle.Print
}

private extension Double {
    var milliSeconds: String {
        return String(format: "%03.2fms", self * 1000)
    }
}