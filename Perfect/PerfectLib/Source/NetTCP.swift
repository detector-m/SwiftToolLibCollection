//
//  NetTCP.swift
//  PerfectLib
//
//  Created by Riven on 16/4/19.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import SwiftGlibc
    let AF_UNSPEC: Int32 = 0
    let AF_INET: Int32 = 2
    let INADDR_NONE = UInt32(0xffffffff)
    let EINPROGRESS = Int32(115)
#else
    import Darwin
#endif

/// Provides an asynhronous IO wrapper around a file descriptor.
/// Fully realized for TCP socket types but can also serve as a base for sockets from other families, such as with `NetNamedPipe`/AF_UNIX.
public class NetTCP: Closeable {
    private var networkFailure: Bool = false
    private var semaphore: Threading.Event?
    private var waitAcceptEvent: LibEvent?
    
    class ReferenceBuffer {
        var b: UnsafeMutablePointer<UInt8>
        let size: Int
        init(size: Int) {
            self.size = size
            self.b = UnsafeMutablePointer<UInt8>.alloc(size)
        }
        deinit {
            self.b.destroy()
            self.b.dealloc(self.size)
        }
    }
    
    var fd: SocketFileDescriptor = SocketFileDescriptor(fd: invalidSocket, family: AF_UNSPEC)
    
    public init() {}
    
    /// Creates an instance which will use the given file descriptor
    /// - parameter fd: The pre-existing file descriptor
    public convenience init(fd: Int32){
        self.init()
        self.fd.fd = fd
        self.fd.family = AF_INET
        self.fd.switchToNBIO()
    }
    
    /// Allocates a new socket if it has not already been done.
    /// The functions `bind` and `connect` will call this method to ensure the socket has been allocated
    /// Sub-classes should override this function in order to create their specialized socket.
    /// All sub-class sockets should be switched to utilize non-blocking IO by calling `SocketFileDescriptor.switchToNBIO()`.
    public func initSocket() {
        if fd.fd == invalidSocket {
            #if os(Linux)
                fd.fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
            #else
                fd.fd = socket(AF_INET, SOCK_STREAM, 0)
            #endif
            fd.family = AF_INET
            fd.switchToNBIO()
        }
    }
    
    public func sockName() -> (String, UInt16) {
        let staticBufferSize = 1024
        var addr = UnsafeMutablePointer<sockaddr_in>.alloc(1)
        let len = UnsafeMutablePointer<socklen_t>.alloc(1)
        let buffer = UnsafeMutablePointer<Int8>.alloc(staticBufferSize)
        defer {
            addr.destroy(); addr.dealloc(1)
            len.destroy(); len.dealloc(1)
            buffer.destroy(); buffer.dealloc(staticBufferSize)
        }
        len.memory = socklen_t(sizeof(sockaddr_in))
        getsockname(fd.fd, UnsafeMutablePointer<sockaddr>(addr), len)
        inet_ntop(fd.family, &addr.memory.sin_addr, buffer, len.memory)
        
        let s = String.fromCString(buffer) ?? ""
        let p = ntohs(addr.memory.sin_port)
        
        return (s, p)
    }
    
    public func peerName() -> (String, UInt16) {
        let staticBufferSize = 1024
        var addr = UnsafeMutablePointer<sockaddr_in>.alloc(1)
        let len = UnsafeMutablePointer<socklen_t>.alloc(1)
        let buffer = UnsafeMutablePointer<Int8>.alloc(staticBufferSize)
        defer {
            addr.destroy(); addr.dealloc(1)
            len.destroy(); len.dealloc(1)
            buffer.destroy(); buffer.dealloc(staticBufferSize)
        }
        len.memory = socklen_t(sizeof(sockaddr_in))
        getpeername(fd.fd, UnsafeMutablePointer<sockaddr>(addr), len)
        inet_ntop(fd.family, &addr.memory.sin_addr, buffer, len.memory)
        
        let s = String.fromCString(buffer) ?? ""
        let p = ntohs(addr.memory.sin_port)
        
        return (s, p)
    }
    
    func isEAgain(err: Int) -> Bool {
        return err == -1 && errno == EAGAIN
    }
    
    func evWhatFor(operation: Int32) -> Int32 {
        return operation
    }
    
    /// Bind the socket on the given port and optional local address
    /// - parameter port: the port on which to bind
    /// - parameter address: the local address, given as a string, on which to bind. Defaults to "0.0.0.0"
    /// - throws: PerfectError.NetworkError
    public func bind(port: UInt16, address: String = "0.0.0.0") throws {
        initSocket()
        
        var addr: sockaddr_in = sockaddr_in()
        let res = makeAddress(&addr, host: address, port: port)
        guard  res != -1
            else {
                try throwNetworkError()
        }
        let i0 = Int8(0)
        #if os(Linux)
            var sock_addr = sockaddr(sa_family: 0, sa_data: (i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0))
        #else
            var sock_addr = sockaddr(sa_len: 0, sa_family: 0, sa_data: (i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0))
        #endif
        memcpy(&sock_addr, &addr, Int(sizeof(sockaddr_in)))
        #if os(Linux)
            let bRes = SwiftGlibc.bind(fd.fd, &sock_addr, socklen_t(sizeof(sockaddr_in)))
        #else
            let bRes = Darwin.bind(fd.fd, &sock_addr, socklen_t(sizeof(sockaddr_in)))
        #endif
        if bRes == -1 {
            try throwNetworkError()
        }
    }
    
    /// Switches the socket to server mode. Socket should have been previously bound using the `bind` function
    public func listen(backlog: Int32 = 128) {
        #if os(Linux)
            SwiftGlibc.listen(fd.fd, backlog)
        #else
            Darwin.listen(fd.fd, backlog)
        #endif
    }
    
    /// Shuts down and closes the socket.
    /// The object may be reused.
    public func close() {
        if fd.fd != invalidSocket {
            #if os(Linux)
                shutdown(fd.fd, 2)
                SwiftGlibc.close(fd.fd)
            #else
                shutdown(fd.fd, SHUT_RDWR)
                Darwin.close(fd.fd)
            #endif
            fd.fd = invalidSocket
            
            if let event = self.waitAcceptEvent {
                event.del()
                self.waitAcceptEvent = nil
            }
            if self.semaphore != nil {
                self.semaphore!.lock()
                self.semaphore!.signal()
                self.semaphore!.unlock()
            }
        }
    }
    
    func recv(buf: UnsafeMutablePointer<Void>, count: Int) -> Int {
        #if os(Linux)
            return SwiftGlibc.recv(self.fd.fd, buf, count, 0)
        #else
            return Darwin.recv(self.fd.fd, buf, count, 0)
        #endif
    }
    func send(buf: UnsafePointer<Void>, count: Int) -> Int {
        #if os(Linux)
            return SwiftGlibc.send(self.fd.fd, buf, count, 0)
        #else
            return Darwin.send(self.fd.fd, buf, count, 0)
        #endif
    }
    
    private func makeAddress(inout sin: sockaddr_in, host: String, port: UInt16) -> Int {
        let theHost: UnsafeMutablePointer<hostent> = gethostbyname(host)
        if theHost == nil {
            if inet_addr(host) == INADDR_NONE {
                endhostent()
                return -1
            }
        }
        let bPort = port.bigEndian
        sin.sin_port = in_port_t(bPort)
        sin.sin_family = sa_family_t(AF_INET)
        if theHost != nil {
            sin.sin_addr.s_addr = UnsafeMutablePointer<UInt32>(theHost.memory.h_addr_list.memory).memory
        }
        else {
            sin.sin_addr.s_addr = inet_addr(host)
        }
        endhostent()
        return 0
    }
    private func completeArray(from: ReferenceBuffer, count: Int) -> [UInt8] {
        var ary = [UInt8](count: count, repeatedValue: 0)
        for index in 0..<count {
            ary[index] = from.b[index]
        }
        return ary
    }
    
    // MARK: - 
    func readBytesFully(into: ReferenceBuffer, read: Int, remaining: Int, timeoutSeconds: Double, completion: ([UInt8]?) -> ()) -> Void {
        let readCount = recv(into.b + read, count: remaining)
        if readCount == 0 {
            completion(nil) // disconnect
        }
        else if self.isEAgain(readCount) {
            // no data available. wait
            self.readBytesFullyIncomplete(into, read: read, remaining: remaining, timeoutSeconds: timeoutSeconds, completion: completion)
        }
        else if readCount < 0 {
            completion(nil) // networking or other error
        }
        else {
            // got some data
            if remaining - readCount == 0 { // done
                completion(completeArray(into, count: read + readCount))
            
            }
            else { // try again for more
                readBytesFully(into, read: read + readCount, remaining: remaining - readCount, timeoutSeconds: timeoutSeconds, completion: completion)
            }
        }
    }
    func readBytesFullyIncomplete(into: ReferenceBuffer, read: Int, remaining: Int, timeoutSeconds: Double, completion: [UInt8]? -> ()) {
        let event: LibEvent = LibEvent(base: LibEvent.eventBase, fd: fd.fd, what: EV_READ, userData: nil) {
            (fd: Int32, w: Int16, ud: AnyObject?) -> () in
            if (Int32(w) & EV_TIMEOUT) == 0 {
                self.readBytesFully(into, read: read, remaining: remaining, timeoutSeconds: timeoutSeconds, completion: completion)
            }
            else {
                completion(nil) // timeout or error
            }
        }
        event.add(timeoutSeconds)
    }
    
    /// Read the indicated number of bytes and deliver them on the provided callback.
    /// - parameter count: The number of bytes to read
    /// - parameter timeoutSeconds: A timeout value of negative one indicates that the request should have no timeout
    /// - parameter completion: the callback on which the results will be delivered. If the timeout occurs before requested number of bytes have been read, a nil object will be delivered to the callback
    public func readBytesFully(count: Int, timeoutSecondes: Double, completion: ([UInt8]?) -> ()) {
        let ptr = ReferenceBuffer(size: count)
        readBytesFully(ptr, read: 0, remaining: count, timeoutSeconds: timeoutSecondes, completion: completion)
    }
    
    /// Read up to the indicated number of bytes and deliver them on the provided callback.
    /// - parameter count: the maximum number of bytes to read.
    /// - parameter completion: the callback on which to deliver the result. If an error occurs during the read then a nil object will be passed to the callback, otherwise, the immdiately available number of bytes, which may be zero, will be passed.
    public func readSomeBytes(count: Int, completion: ([UInt8]?) -> ()) {
        let ptr = ReferenceBuffer(size: count)
        let readCount = recv(ptr.b, count: count)
        if readCount == 0 {
            completion(nil)
        }
        else if self.isEAgain(readCount) {
            completion([UInt8]())
        }
        else if readCount == -1 {
            completion(nil)
        }
        else {
            completion(completeArray(ptr, count: readCount))
        }
    }
    
    /// Write the string and call the callback with the number of bytes which were written.
    /// - parameter s: The string to write. the string will be written based on its UTF-8 encoding
    /// - parameter completion: The callback which will be called once the write has completed. the callback will be passed the number of bytes which were successfuly written, which may be zero.
    public func write(s: String, completion: (Int) -> ()) {
        writeString(s, completion: completion)
    }
    
    public func write(bytes: [UInt8], completion: (Int) -> ()) {
        writeBytes(bytes, completion: completion)
    }
    
    public func writeString(s: String, completion: (Int) -> ()) {
        writeBytes([UInt8](s.utf8), completion: completion)
    }
    /// Write the indicated bytes and call the callback with the number of bytes which were written.
    public func writeBytes(bytes: [UInt8], completion: (Int) -> ()) {
        writeBytes(bytes, dataPostion: 0, length: bytes.count, completion: completion)
    }
    
    /// write the indicate bytes and reutrn true if all data was sent.
    /// - parameter bytes: the array of UInt8 to write.
    public func writeBytesFully(bytes: [UInt8]) -> Bool {
        let length = bytes.count
        var totalSent = 0
        let ptr = UnsafeMutablePointer<UInt8>(bytes)
        var s: Threading.Event?
        var what: Int32 = 0
        
        let waitFunc = {
            let event: LibEvent = LibEvent(base: LibEvent.eventBase, fd: self.fd.fd, what: EV_WRITE, userData: nil) {
                (fd: Int32, w: Int16, ud: AnyObject?) -> () in
                what = Int32(w)
                s!.lock()
                s!.signal()
                s!.unlock()
            }
            event.add()
        }
        while length > 0 {
            let sent = send(ptr.advancedBy(totalSent), count: length - totalSent)
            if sent == length {
                return true
            }
            if s == nil {
                s = Threading.Event()
            }
            if sent == -1 {
                if isEAgain(sent) { // flow
                    s!.lock()
                    waitFunc()
                }
                else { // error
                    break
                }
            }
            else {
                totalSent += sent
                if totalSent == length {
                    return true
                }
                s!.lock()
                waitFunc()
            }
            s!.wait()
            s!.unlock()
            if what != EV_WRITE {
                break
            }
        }
        
        return totalSent == length
    }
    
    /// Write the indicated bytes and call the callback with the number of bytes which were written.
    /// - parameter bytes: the array of UInt8 to write.
    /// - parameter dataPosition: The offset within `bytes` at which to begin writing.
    /// - parameter length: the number of bytes to write
    /// - parameter completion: The callback which will be called once the write has completed. the callback will be passed the number of bytes which were successfuly written, which may be zero
    public func writeBytes(bytes: [UInt8], dataPostion: Int, length: Int, completion: (Int) -> ()) {
        let ptr = UnsafeMutablePointer<UInt8>(bytes).advancedBy(dataPostion)
        writeBytes(ptr, wrote: 0, length: length, completion: completion)
    }
    func writeBytes(ptr: UnsafeMutablePointer<UInt8>, wrote: Int, length: Int, completion: (Int) -> ()) {
        let sent = send(ptr, count: length)
        if isEAgain(sent) {
            writeBytesIncomplete(ptr, wrote: wrote, length: length, completion: completion)
        }
        else if sent == -1 {
            completion(-1)
        }
        else if sent < length {
            // flow control
            writeBytesIncomplete(ptr.advancedBy(sent), wrote: wrote + sent, length: length - sent, completion: completion)
        }
        else {
            completion(wrote + sent)
        }
    }
    func writeBytesIncomplete(nptr: UnsafeMutablePointer<UInt8>, wrote: Int, length: Int, completion: (Int) -> ()) {
        let event: LibEvent = LibEvent(base: LibEvent.eventBase, fd: fd.fd, what: EV_WRITE, userData: nil) {
            (fd: Int32, w: Int16, ud: AnyObject?) -> () in
            self.writeBytes(nptr, wrote: wrote, length: length, completion: completion)
        }
        event.add()
    }
    
    /// Connect to the indicated server
    /// - parameter address: the server's address, expressed as a string.
    /// - parameter port: the port on which to connect
    /// - parameter timeoutSeconds: the number of seconds to wait for the connection to complete. A timeout of negative one indicates that there is no timeout.
    /// - parameter callback: the closure which will be called when the connection completes. if the connection completes successfully then the current NetTCP instance will be passed to the callback, otherwise, a nil object will be passed.
    /// - returns: `PerfectError.NetworkError`
    public func connect(address: String, port: UInt16, timeoutSeconds: Double, callback: (NetTCP?) -> ()) throws {
        initSocket()
        
        var addr: sockaddr_in = sockaddr_in()
        let res = makeAddress(&addr, host: address, port: port)
        guard res != -1
            else {
                try throwNetworkError()
        }
        let i0 = Int8(0)
        #if os(Linux)
            var sock_addr = sockaddr(sa_family: 0, sa_data: (i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0))
        #else
            var sock_addr = sockaddr(sa_len: 0, sa_family: 0, sa_data: (i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0, i0))
        #endif
        memcpy(&sock_addr, &addr, Int(sizeof(sockaddr_in)))
        #if os(Linux)
            let cRes = SwiftGlibc.connect(fd.fd, &sock_addr, socklen_t(sizeof(sockaddr_in)))
        #else
            let cRes = Darwin.connect(fd.fd, &sock_addr, socklen_t(sizeof(sockaddr_in)))
        #endif
        if cRes != -1 {
            callback(self)
        }
        else {
            guard errno == EINPROGRESS
                else {
                    try throwNetworkError()
            }
            let event: LibEvent = LibEvent(base: LibEvent.eventBase, fd: fd.fd, what: EV_WRITE, userData: nil) {
                (fd: Int32, w: Int16, ud: AnyObject?) -> () in
                if (Int32(w) & EV_TIMEOUT) != 0 {
                    callback(nil)
                }
                else {
                    callback(self)
                }
            }
            event.add(timeoutSeconds)
        }
    }
    
    /// Accept a new client connection and pass the result to the callback
    /// - parameter timeoutSeconds: the number of seconds to wait for a new connection to arrive. A timeout value of negative one indicates that there is no timeout.
    /// - parameter callback: the closure which will be called when the accept completes. the parameter will be a newly allocated instance of NetTCP which represents the client.
    /// - returns: `PerfectError.NetworkError`
    public func accept(timeoutSecnods: Double, callback: (NetTCP?) -> ()) throws {
        #if os(Linux)
            let accRes = SwiftGlibc.accept(fd.fd, UnsafeMutablePointer<sockaddr>(nil), UnsafeMutablePointer<socklen_t>(nil))
        #else
            let accRes = Darwin.accept(fd.fd, UnsafeMutablePointer<sockaddr>(nil), UnsafeMutablePointer<socklen_t>(nil))
        #endif
        if accRes != -1 {
            let newTcp = self.makeFromFd(accRes)
            callback(newTcp)
        }
        else {
            guard self.isEAgain(Int(accRes))
                else {
                    try throwNetworkError()
            }
            let event: LibEvent = LibEvent(base: LibEvent.eventBase, fd: fd.fd, what: self.evWhatFor(EV_READ), userData: nil) {
                (fd: Int32, w: Int16, ud: AnyObject?) -> () in
                if (Int32(w) & EV_TIMEOUT) != 0 {
                    callback(nil)
                }
                else {
                    do {
                        try self.accept(timeoutSecnods, callback: callback)
                    } catch {
                        callback(nil)
                    }
                }
            }
            event.add(timeoutSecnods)
        }
    }
    
    private func tryAccept() -> Int32 {
        #if os(Linux)
            let accRes = SwiftGlibc.accept(fd.fd, UnsafeMutablePointer<sockaddr>(nil), UnsafeMutablePointer<socklen_t>(nil))
        #else
            let accRes = Darwin.accept(fd.fd, UnsafeMutablePointer<sockaddr>(nil), UnsafeMutablePointer<socklen_t>(nil))
        #endif
        return accRes
    }
    
    private func waitAccept() {
        let event: LibEvent = LibEvent(base: LibEvent.eventBase, fd: fd.fd, what: self.evWhatFor(EV_READ), userData: nil) {
            [weak self] (fd: Int32, w: Int16, ud: AnyObject?) -> () in
            self?.waitAcceptEvent = nil
            if (Int32(w) & EV_TIMEOUT) != 0 {
                print("huh?")
            }
            else {
                self?.semaphore!.lock()
                self?.semaphore!.signal()
                self?.semaphore!.unlock()
            }
        }
        self.waitAcceptEvent = event
        event.add()
    }
    
    /// Accept a series of new client connections and pass them to the callback. this function does not return outside of catastrophic error.
    /// - parameter callback: The closure which will be called when the accept completes. the parameter will be a newly allocated instance of NetTCP which represents the client.
    public func forEachAccept(callback: (NetTCP?) -> ()) {
        guard self.semaphore == nil
            else {
                return
        }
        self.semaphore = Threading.Event()
        defer {
            self.semaphore = nil
        }
        
        repeat {
            let accRes = tryAccept()
            if accRes != -1 {
                Threading.dispatchBlock {
                    callback(self.makeFromFd(accRes))
                }
            }
            else if self.isEAgain(Int(accRes)) {
                self.semaphore!.lock()
                waitAccept()
                self.semaphore!.wait()
                self.semaphore!.unlock()
            }
            else {
                let errStr = String.fromCString(strerror(Int32(errno))) ?? "NO MESSAGE"
                print("Unexpected networking error: \(errno) '\(errStr)'")
                networkFailure = true
            }
        } while !networkFailure && self.fd.fd != invalidSocket
        return
    }
    
    func makeFromFd(fd: Int32) -> NetTCP {
        return NetTCP(fd: fd)
    }
}
