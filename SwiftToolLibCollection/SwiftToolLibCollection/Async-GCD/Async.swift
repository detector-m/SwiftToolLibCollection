//
//  Async.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/6.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

// MARK: - DSL for GCD Queues
/*
    `GCD` is an empty struct with convenience static functions to get `dispatch_queue_t` of different quality of service classes, as provided by `dispatch_get_global_queue`
*/
private struct GCD {
    /*
    QOS_CLASS_USER_INTERACTIVE： user interactive等级表示任务需要被立即执行以提供好的用户体验。使用它来更新UI，响应事件以及需要低延时的小工作量任务。这个等级的工作总量应该保持较小规模。
    QOS_CLASS_USER_INITIATED：user initiated等级表示任务由UI发起并且可以异步执行。它应该用在用户需要即时的结果同时又要求可以继续交互的任务。
    QOS_CLASS_UTILITY：utility等级表示需要长时间运行的任务，常常伴随有用户可见的进度指示器。使用它来做计算，I/O，网络，持续的数据填充等任务。这个等级被设计成节能的。
    QOS_CLASS_BACKGROUND：background等级表示那些用户不会察觉的任务。使用它来执行预加载，维护或是其它不需用户交互和对时间不敏感的任务。
    */
    typealias DSLQueue = dispatch_queue_t
    static func mainQueue() -> DSLQueue {
        return dispatch_get_main_queue()
        // Don't ever use dispatch_get_global_queue(qos_class_main(), 0) re https://gist.github.com/duemunk/34babc7ca8150ff81844
    }
    
    static func userInteractiveQueue() -> DSLQueue {
        return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
    }
    
    static func userInitiatedQueue() -> DSLQueue {
        return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
    }
    
    static func utilityQueue() -> DSLQueue {
        return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
    }
    
    static func backgroundQueue() -> DSLQueue {
        return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
    }
}

// MARK: - Async - Struct
/**
The **Async** struct is the main part of the Async.framework. Handles a internally `dispatch_block_t`.

Chainable dispatch blocks with GCD:

Async.background {
// Run on background queue
}.main {
// Run on main queue, after the previous block
}

All moderns queue classes:

Async.main {}
Async.userInteractive {}
Async.userInitiated {}
Async.utility {}
Async.background {}

Custom queues:

let customQueue = dispatch_queue_create("Label", DISPATCH_QUEUE_CONCURRENT)
Async.customQueue(customQueue) {}

Dispatch block after delay:

let seconds = 0.5
Async.main(after: seconds) {}

Cancel blocks not yet dispatched

let block1 = Async.background {
// Some work
}
let block2 = block1.background {
// Some other work
}
Async.main {
// Cancel async to allow block1 to begin
block1.cancel() // First block is NOT cancelled
block2.cancel() // Second block IS cancelled
}

Wait for block to finish:

let block = Async.background {
// Do stuff
}
// Do other stuff
// Wait for "Do stuff" to finish
block.wait()
// Do rest of stuff

- SeeAlso: Grand Central Dispatch
*/
public struct Async {
    // MARK: - Private properties and init
    private let block: dispatch_block_t
    private init(_ block: dispatch_block_t) {
        self.block = block
    }
    
    // MARK: - Static methods
    public static func main(after after: Double? = nil, block: dispatch_block_t) -> Async {
        return Async.async(after, block: block, queue: GCD.mainQueue())
    }
    
    public static func userInteractive(after after: Double? = nil, block: dispatch_block_t) -> Async {
        return Async.async(after, block: block, queue: GCD.userInteractiveQueue())
    }
    
    public static func userInitiated(after after: Double? = nil, block: dispatch_block_t) -> Async {
        return Async.async(after, block: block, queue: GCD.userInitiatedQueue())
    }
    
    public static func utility(after after: Double? = nil, block: dispatch_block_t) -> Async {
        return Async.async(after, block: block, queue: GCD.utilityQueue())
    }
    
    public static func background(after after: Double? = nil, block: dispatch_block_t) -> Async {
        return Async.async(after, block: block, queue: GCD.backgroundQueue())
    }
    
    // Custom
    public static func customQueue(queue: dispatch_queue_t, after: Double? = nil, block: dispatch_block_t) -> Async {
        return Async.async(after, block: block, queue: queue)
    }
    
    // MARK: - Private Static Methods
    private static func async(seconds: Double? = nil, block chainingBlock: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        if let seconds = seconds {
            return asyncAfter(seconds, block: chainingBlock, queue: queue)
        }
        
        return asyncNow(chainingBlock, queue: queue)
    }
    
    private static func asyncNow(block: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        let _block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, block)
        dispatch_async(queue, _block)
        
        return Async(_block)
    }
    
    private static func asyncAfter(seconds: Double, block: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        let nanoSecondes = Int64(seconds * Double(NSEC_PER_SEC))
        let time = dispatch_time(DISPATCH_TIME_NOW, nanoSecondes)
        
        return at(time, block: block, queue: queue)
    }
    
    private static func at(time: dispatch_time_t, block: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        let _block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, block)
        
        dispatch_after(time, queue, _block)
        
        return Async(_block)
    }
    
    // MARK: - Instance methods (matches static ones)
    public func main(after after: Double? = nil, chainningBlock:  dispatch_block_t) -> Async {
        return chain(after, block: block, queue: GCD.mainQueue())
    }
    
    public func userInteractive(after after: Double? = nil, chainingBlock: dispatch_block_t) -> Async {
        return chain(after, block: chainingBlock, queue: GCD.userInteractiveQueue())
    }
    
    public func userInitiated(after after: Double? = nil, chainingBlock: dispatch_block_t) -> Async {
        return chain(after, block: chainingBlock, queue: GCD.userInitiatedQueue())
    }
    
    public func utility(after after: Double? = nil, chainingBlock: dispatch_block_t) -> Async {
        return chain(after, block: block, queue: GCD.utilityQueue())
    }
    
    public func background(after after: Double? = nil, chainingBlock: dispatch_block_t) -> Async {
        return chain(after, block: chainingBlock, queue: GCD.backgroundQueue())
    }
    
    public func customQueue(queue: dispatch_queue_t, after: Double? = nil, chainingBlock: dispatch_block_t) -> Async {
        return chain(after, block: chainingBlock, queue: queue)
    }
    
    // MARK: - Instance methods
    /**
    Convenience function to call `dispatch_block_cancel()` on the encapsulated block.
    Cancels the current block, if it hasn't already begun running to GCD.
    
    Usage:
    
    let block1 = Async.background {
    // Some work
    }
    let block2 = block1.background {
    // Some other work
    }
    Async.main {
    // Cancel async to allow block1 to begin
    block1.cancel() // First block is NOT cancelled
    block2.cancel() // Second block IS cancelled
    }
    
    */
    public func cancel() {
        dispatch_block_cancel(block)
    }
    
    public func wait(sencods seconds: Double? = nil) {
        if seconds != nil {
            let nanoSeconds = Int64(seconds! * Double(NSEC_PER_SEC))
            let time = dispatch_time(DISPATCH_TIME_NOW, nanoSeconds)
            dispatch_block_wait(block, time)
        }
        else {
            dispatch_block_wait(block, DISPATCH_TIME_FOREVER)
        }
    }
    
    // MARK: - Private instance methods
    private func chain(seconds: Double? = nil, block chainingBlock: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        if let seconds = seconds {
            return chainAfter(seconds, block: block, queue: queue)
        }
        
        return chainNow(block: block, queue: queue)
    }
    
    private func chainNow(block chainingBlock: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        // See Async.async() for comments
        let _chainingBlock = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, chainingBlock)
        dispatch_block_notify(block, queue, _chainingBlock)
        
        return Async(_chainingBlock)
    }
    
    private func chainAfter(seconds: Double, block chainingBlock: dispatch_block_t, queue: dispatch_queue_t) -> Async {
        let _chainingBlock = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, chainingBlock)
        let chainingWrapperBlock: dispatch_block_t = {
            let nanoSeconds = Int64(seconds * Double(NSEC_PER_SEC))
            let time = dispatch_time(DISPATCH_TIME_NOW, nanoSeconds)
            dispatch_after(time, queue, _chainingBlock)
        }
        
        let _chainingWrapperBlock = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, chainingWrapperBlock)
        dispatch_block_notify(block, queue, _chainingWrapperBlock)
        
        return Async(_chainingBlock)
    }
}

// MARK: - Apply - DSL For 'dispath_apply'
/**
`Apply` is an empty struct with convenience static functions to parallelize a for-loop, as provided by `dispatch_apply`.

Apply.background(100) { i in
// Calls blocks in parallel
}

`Apply` runs a block multiple times, before returning. If you want run the block asynchronously from the current thread, wrap it in an `Async` block:

Async.background {
Apply.background(100) { i in
// Calls blocks in parallel asynchronously
}
}

- SeeAlso: Grand Central Dispatch, dispatch_apply
*/
public struct Apply {
    /*
        Block is run any given amount of times on a queue with a quality of service of QOS_CLASS_USER_INTERACTIVE. The block is being passed an index parameter.
    */
    public static func userInteractive(iterations: Int, block: Int -> ()) {
        dispatch_apply(iterations, GCD.userInteractiveQueue(), block)
    }
    
    public static func userInitiated(iterations: Int, block: Int -> ()) {
        dispatch_apply(iterations, GCD.userInitiatedQueue(), block)
    }
    
    public static func utility(iterations: Int, block: Int -> ()) {
        dispatch_apply(iterations, GCD.utilityQueue(), block)
    }
    
    public static func background(iterations: Int, block: Int -> ()) {
        dispatch_apply(iterations, GCD.backgroundQueue(), block)
    }
    
    public static func customQueue(iterations: Int, queue: dispatch_queue_t, block: Int -> ()) {
        dispatch_apply(iterations, queue, block)
    }
}

// MARK: - Group 
/**
The **AsyncGroup** struct facilitates working with groups of asynchronous blocks. Handles a internally `dispatch_group_t`.

Multiple dispatch blocks with GCD:

let group = AsyncGroup()
group.background {
// Run on background queue
}
group.utility {
// Run on untility queue, after the previous block
}
group.wait()

All moderns queue classes:

group.main {}
group.userInteractive {}
group.userInitiated {}
group.utility {}
group.background {}

Custom queues:

let customQueue = dispatch_queue_create("Label", DISPATCH_QUEUE_CONCURRENT)
group.customQueue(customQueue) {}

Wait for group to finish:

let group = AsyncGroup()
group.background {
// Do stuff
}
group.background {
// Do other stuff in parallel
}
// Wait for both to finish
group.wait()
// Do rest of stuff

- SeeAlso: Grand Central Dispatch
*/
public struct AsyncGroup {
    // MARK: - Private properties and init
    var group: dispatch_group_t
    
    public init() {
        group = dispatch_group_create()
    }
    
    private func async(block block: dispatch_block_t, queue: dispatch_queue_t) {
        dispatch_group_async(group, queue, block)
    }
    
    public func enter() {
        dispatch_group_enter(group)
    }
    
    public func leave() {
        dispatch_group_leave(group)
    }
    
    // MARK: - Instance methods
    public func main(block: dispatch_block_t) {
        async(block: block, queue: GCD.mainQueue())
    }
    
    public func userInteractive(block: dispatch_block_t) {
        async(block: block, queue: GCD.userInteractiveQueue())
    }
    
    public func userInitiated(block: dispatch_block_t) {
        async(block: block, queue: GCD.userInitiatedQueue())
    }
    
    public func utility(block: dispatch_block_t) {
        async(block: block, queue: GCD.utilityQueue())
    }
    
    public func background(block: dispatch_block_t) {
        async(block: block, queue: GCD.backgroundQueue())
    }
    
    public func customQueue(queue: dispatch_queue_t, block: dispatch_block_t) {
        async(block: block, queue: queue)
    }
    
    public func waite(seconds seconds: Double! = nil) {
        if seconds != nil {
            let nanoSeconds = Int64(seconds * Double(NSEC_PER_SEC))
            let time = dispatch_time(DISPATCH_TIME_NOW, nanoSeconds)
            dispatch_group_wait(group, time)
        }
        else {
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
        }
    }
}

// MARK: - Extension for `qos_class_t`
public extension qos_class_t {
    /**
     Description of the `qos_class_t`. E.g. "Main", "User Interactive", etc. for the given Quality of Service class.
     */
    var description: String {
        get {
            switch self {
            case qos_class_main(): return "Main"
            case QOS_CLASS_USER_INTERACTIVE: return "User Interactive"
            case QOS_CLASS_USER_INITIATED: return "User Initiated"
            case QOS_CLASS_DEFAULT: return "Default"
            case QOS_CLASS_UTILITY: return "Utility"
            case QOS_CLASS_BACKGROUND: return "Background"
            case QOS_CLASS_UNSPECIFIED: return "Unspecified"
            default: return "Unknown"
            }
        }
    }
}