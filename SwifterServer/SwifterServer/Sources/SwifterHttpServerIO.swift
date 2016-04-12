//
//  SwifterHttpServerIO.swift
//  SwifterServer
//
//  Created by Riven on 16/4/11.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import Glibc
    import NSLinux
#endif
import Foundation

public class SwifterHttpServerIO {
    private var listenSocket: SwifterSocket = SwifterSocket(socketFileDescriptor: -1)
    private var clientSockets: Set<SwifterSocket> = []
    private let clientSocketsLock = NSLock()
    
    public func start(listenPort: in_port_t = 8080) throws {
        stop()
        listenSocket = try SwifterSocket.tcpSocketForListen(listenPort)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            [weak self] in
            while let socket = try? self?.listenSocket.acceptClientSocket() {
                self!.lock(self!.clientSocketsLock) {
                    self?.clientSockets.insert(socket!)
                }
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                    self?.handleConnection(socket!)
                    self?.lock((self?.clientSocketsLock)!) {
                        self?.clientSockets.remove(socket!)
                    }
                })
            }
            
            self!.stop()
        }
    }
    
    public func stop() {
        listenSocket.release()
        lock(self.clientSocketsLock) {
            for socket in self.clientSockets {
                socket.shutdown()
            }
            self.clientSockets.removeAll(keepCapacity: true)
        }
    }
    
    public func dispath(method: String, path: String) -> ([String: String], SwifterHttpRequest -> SwifterHttpResponse) {
        return ([:], { _ in SwifterHttpResponse.NotFound})
    }
    
    private func handleConnection(socket: SwifterSocket) {
        let address = try? socket.peername()
        let parser = SwifterHttpParser()
        while let request = try? parser.readHttpRequest(socket) {
            let request = request
            let (params, handler) = self.dispath(request.method, path: request.path)
            request.address = address
            request.params = params
            let response = handler(request)
            var keepConnection = parser.supportsKeepAlive(request.headers)
            do {
                keepConnection = try self.respond(socket, response: response, keepAlive: keepConnection)
            } catch {
                print("Failed to send response: \(error)")
                break
            }
            if let session = response.socketSession() {
                session(socket)
                break
            }
            if !keepConnection { break }
        }
        
        socket.release()
    }
    
    private func lock(handle: NSLock, closure: () -> ()) {
        handle.lock()
        closure()
        handle.unlock()
    }
    
    private struct InnerWriteContext: SwifterHttpResponseBodyWriter {
        let socket: SwifterSocket
        func write(data: [UInt8]) -> Void {
            write(ArraySlice(data))
        }
        
        func write(data: ArraySlice<UInt8>) -> Void {
            do {
                try socket.writeUInt8(data)
            } catch {
                print("\(error)")
            }
        }
    }
    
    private func respond(socket: SwifterSocket, response: SwifterHttpResponse, keepAlive: Bool) throws -> Bool {
        try socket.writeUTF8("HTTP/1.1 \(response.statusCode()) \(response.reasonPhrase())\r\n")
        let content = response.content()
        if content.length >= 0 {
            try socket.writeUTF8("Content-Length: \(content.length)\r\n")
        }
        
        if keepAlive && content.length != -1 {
            try socket.writeUTF8("Connection: keep-alive\r\n")
        }
        
        for (name, value) in response.headers() {
            try socket.writeUTF8("\(name):\(value)\r\n")
        }
        try socket.writeUTF8("\r\n")
        if let writeClouse = content.write {
            let context = InnerWriteContext(socket: socket)
            try writeClouse(context)
        }
        
        return keepAlive && content.length != -1
    }
}




