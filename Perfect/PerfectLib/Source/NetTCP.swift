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
}
