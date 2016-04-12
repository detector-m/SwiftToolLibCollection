//
//  SwifterSocket.swift
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

/* Low level routines for POSIX sockets */
public enum SwifterSocketError: ErrorType {
    case SocketCreationFailed(String)
    case SocketSettingReUseAddrFailed(String)
    case BindFailed(String)
    case ListenFailed(String)
    case WriteFailed(String)
    case GetPeerNameFailed(String)
    case ConvertingPeerNameFailed
    case GetNameInfoFailed(String)
    case AcceptFailed(String)
    case ReceiveFailed(String)
}

public class SwifterSocket: Hashable, Equatable {
    // MARK: - 
    private let socketFileDescriptor: Int32
    public init(socketFileDescriptor: Int32) {
        self.socketFileDescriptor = socketFileDescriptor
    }
    
    // MARK: - HAshable
    public var hashValue: Int {
        return Int(self.socketFileDescriptor)
    }
    
    public func release() {
        SwifterSocket.release(self.socketFileDescriptor)
    }
    public func shutdown() {
        SwifterSocket.shutdown(self.socketFileDescriptor)
    }
    
    public static func tcpSocketForListen(port: in_port_t, maxPendingConnection: Int32 = SOMAXCONN) throws -> SwifterSocket {
        #if os(Linux)
            let socketFileDescriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
            let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        
        if socketFileDescriptor == -1 {
            throw SwifterSocketError.SocketCreationFailed(SwifterSocket.descriptionOfLastError())
        }
        
        var value: Int32 = 1
        if setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(sizeof(Int32))) == -1 {
            let details = SwifterSocket.descriptionOfLastError()
            SwifterSocket.release(socketFileDescriptor)
            throw SwifterSocketError.SocketSettingReUseAddrFailed(details)
        }
        SwifterSocket.setNoSigPipe(socketFileDescriptor)
        
        #if os(Linux)
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = SwifterSocket.htonsPort(port)
            addr.sin_addr = in_addr(s_addr: s_addr_t(0))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        #else
            var addr = sockaddr_in()
            addr.sin_len = __uint8_t(sizeof(sockaddr_in))
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = SwifterSocket.htonsPort(port)
            addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        #endif

        var bindAddr = sockaddr()
        memcpy(&bindAddr, &addr, Int(sizeof(sockaddr_in)))
        if bind(socketFileDescriptor, &bindAddr, socklen_t(sizeof(sockaddr_in))) == -1 {
            let details = SwifterSocket.descriptionOfLastError()
            SwifterSocket.release(socketFileDescriptor)
            throw SwifterSocketError.BindFailed(details)
        }
        
        if listen(socketFileDescriptor, maxPendingConnection) == -1 {
            let details = SwifterSocket.descriptionOfLastError()
            SwifterSocket.release(socketFileDescriptor)
            throw SwifterSocketError.ListenFailed(details)
        }
        
        return SwifterSocket(socketFileDescriptor: socketFileDescriptor)
    }
    
    public func acceptClientSocket() throws -> SwifterSocket {
        var addr = sockaddr()
        var len: socklen_t = 0
        let clientSocket = accept(self.socketFileDescriptor, &addr, &len)
        if clientSocket == -1 {
            throw SwifterSocketError.AcceptFailed(SwifterSocket.descriptionOfLastError())
        }
        SwifterSocket.setNoSigPipe(clientSocket)
        return SwifterSocket(socketFileDescriptor: clientSocket)
    }
    
    public func peername() throws -> String {
        var addr = sockaddr(), len: socklen_t = socklen_t(sizeof(sockaddr))
        if getpeername(self.socketFileDescriptor, &addr, &len) != 0 {
            throw SwifterSocketError.GetPeerNameFailed(SwifterSocket.descriptionOfLastError())
        }
        var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
        if getnameinfo(&addr, len, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
            throw SwifterSocketError.GetPeerNameFailed(SwifterSocket.descriptionOfLastError())
        }
        guard let name = String.fromCString(hostBuffer)
            else {
                throw SwifterSocketError.ConvertingPeerNameFailed
        }
        
        return name
    }
    
    // MARK: - Read And Write
    public func writeUTF8(string: String) throws {
        try writeUInt8(ArraySlice(string.utf8))
    }
    public func writeUInt8(data: [UInt8]) throws {
        try writeUInt8(ArraySlice(data))
    }
    public func writeUInt8(data: ArraySlice<UInt8>) throws {
        try data.withUnsafeBufferPointer {
            [unowned self] in
            var sent = 0
            while sent < data.count {
                #if os(Linux)
                    let s = send(self.socketFileDescriptor, &0.baseAddress + sent, Int(data.count - sent), Int32(MSG_NOSIGNAL))
                #else
                    let s = write(self.socketFileDescriptor, $0.baseAddress + sent, Int(data.count - sent))
                #endif
                if s <= 0 {
                    throw SwifterSocketError.WriteFailed(SwifterSocket.descriptionOfLastError())
                }
                sent += s
            }
        }
    }
    
    public func read() throws -> UInt8 {
        var buffer = [UInt8](count: 1, repeatedValue: 0)
        let next = recv(self.socketFileDescriptor as Int32, &buffer, Int(buffer.count), 0)
        if next <= 0 {
            throw SwifterSocketError.ReceiveFailed(SwifterSocket.descriptionOfLastError())
        }
        
        return buffer[0]
    }
    
    private static let CR = UInt8(13)
    private static let NL = UInt8(10)
    
    public func readLine() throws -> String {
        var characters: String = ""
        var n: UInt8 = 0
        
        repeat {
            n = try self.read()
            if n > SwifterSocket.CR {
                characters.append(Character(UnicodeScalar(n)))
            }
        } while n != SwifterSocket.NL
        
        return characters
    }
    
    
    
    // MARK: - Private
    private static func descriptionOfLastError() -> String {
        return String.fromCString(UnsafePointer(strerror(errno))) ?? "Error: \(errno)"
    }
    
    private static func setNoSigPipe(socket: Int32) {
        #if os(Linux)
            // There is no SO_NOSIGPIPE in Linux (nor some other systems). You can instead use the MSG_NOSIGNAL flag when calling send(),
            // or use signal(SIGPIPE, SIG_IGN) to make your entire application ignore SIGPIPE.
        #else
            // Prevents crashes when blocking calls are pending and the app is paused (via Home button).
            var no_sig_pipe: Int32 = 1
            setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(sizeof(Int32)))
        #endif
    }
    
    private static func shutdown(socket: Int32) {
        #if os(Linux)
            shutdown(socket, Int32(SHUT_RDWR))
        #else
            Darwin.shutdown(socket, SHUT_RDWR)
        #endif
        
        close(socket)
    }
    
    private static func release(socket: Int32) {
        SwifterSocket.shutdown(socket)
    }
    private static func htonsPort(port: in_port_t) -> in_port_t {
        #if os(Linux)
            return htons(port)
        #else
            let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
            return isLittleEndian ? _OSSwapInt16(port) : port
        #endif
    }
}

public func ==(socket1: SwifterSocket, socket2: SwifterSocket) -> Bool {
    return socket1.socketFileDescriptor == socket2.socketFileDescriptor
}
