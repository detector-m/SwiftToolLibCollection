//
//  HTTP2.swift
//  PerfectLib
//
//  Created by Riven on 16/4/25.
//  Copyright © 2016年 Riven. All rights reserved.
//

// NOTE: This HTTP/2 client is competent enough to operate with Apple's push notification service, but
// still lacks some functionality to make it general purpose. Consider it a work in-progress.

#if os(Linux)
    import SwiftGlibc
#endif

let HTTP2_DATA = UInt8(0x0)
let HTTP2_HEADERS = UInt8(0x01)
let HTTP2_PRIORITY = UInt8(0x02)
let HTTP2_RST_STREAM = UInt8(0x03)
let HTTP2_SETTINGS = UInt8(0x04)
let HTTP2_PUSH_PROMISE = UInt8(0x05)
let HTTP2_PING = UInt8(0x06)
let HTTP2_GOAWAY = UInt8(0x07)
let HTTP2_WINDOW_UPDATE = UInt8(0x8)
let HTTP2_CONTINUATION = UInt8(0x9)

let HTTP2_END_STREAM = UInt8(0x1)
let HTTP2_END_HEADERS = UInt8(0x4)
let HTTP2_PADDED = UInt8(0x8)
let HTTP2_FLAG_PRIORITY = UInt8(0x20)
let HTTP2_SETTINGS_ACK = HTTP2_END_STREAM
let HTTP2_PING_ACK = HTTP2_END_STREAM

let SETTINGS_HEADER_TABLE_SIZE = UInt16(0x1)
let SETTINGS_ENABLE_PUSH = UInt16(0x2)
let SETTINGS_MAX_CONCURRENT_STREAMS = UInt16(0x3)
let SETTINGS_INITIAL_WINDOW_SIZE = UInt16(0x4)
let SETTINGS_MAX_FRAME_SIZE = UInt16(0x5)
let SETTINGS_MAX_HEADER_LIST_SIZE = UInt16(0x6)

public struct HTTP2Frame {
    let length: UInt32 // 24-bit
    let type: UInt8
    let flags: UInt8
    let streamId: UInt32 // 31-bit
    var payload: [UInt8]?
    
    var typeStr: String {
        switch self.type {
        case HTTP2_DATA:
            return "HTTP2_DATA"
        case HTTP2_HEADERS:
            return "HTTP2_HEADERS"
        case HTTP2_PRIORITY:
            return "HTTP2_PRIORITY"
        case HTTP2_RST_STREAM:
            return "HTTP2_RST_STREAM"
        case HTTP2_SETTINGS:
            return "HTTP2_SETTINGS"
        case HTTP2_PUSH_PROMISE:
            return "HTTP2_PUSH_PROMISE"
        case HTTP2_PING:
            return "HTTP2_PING"
        case HTTP2_GOAWAY:
            return "HTTP2_GOAWAY"
        case HTTP2_WINDOW_UPDATE:
            return "HTTP2_WINDOW_UPDATE"
        case HTTP2_CONTINUATION:
            return "HTTP2_CONTINUATION"
        default:
            return "UNKNOWN_TYPE"
        }
    }
    
    var flagsStr: String {
        var s = ""
        if flags == 0 {
            s.appendContentsOf("NO FLAGS")
        }
        if (flags & HTTP2_END_STREAM) != 0 {
            s.appendContentsOf(" +HTTP2_END_STREAM")
        }
        if (flags & HTTP2_END_HEADERS) != 0 {
            s.appendContentsOf(" +HTTP2_END_HEADERS")
        }
        return s
    }
    
    func headerBytes() -> [UInt8] {
        var data = [UInt8]()
        
        let l = htonl(length) >> 8
        data.append(UInt8(l & 0xff))
        data.append(UInt8((l >> 8) & 0xff))
        data.append(UInt8((l >> 16) & 0xff))
        
        data.append(type)
        data.append(flags)
        
        let s = htonl(streamId)
        data.append(UInt8(s & 0xff))
        data.append(UInt8((s >> 8) & 0xff))
        data.append(UInt8((s >> 16) & 0xff))
        data.append(UInt8((s >> 24) & 0xff))
        return data
    }
}

class HTTP2Connection: WebConnection {
    weak var client: HTTP2Client?
    var status = (200, "OK")
    
    init(client: HTTP2Client) {
        self.client = client
    }
    
    /// The TCP based connection
    var connection: NetTCP {
        if let c = self.client {
            return c.net
        }
        return NetTCP() // Return non-connected
    }
    /// The parameters sent by the client
    var requestParams = [String:String]()
    /// Any non mime based request body data
    var stdin: [UInt8]? { return nil }
    /// Parsed mime based body data
    var mimes: MimeReader? { return nil }
    
    /// Set the response status code and message. For example, 200, "OK".
    func setStatus(code: Int, msg: String) {
        self.status = (code, msg)
    }
    /// Get the response status code and message.
    func getStatus() -> (Int, String) { return self.status }
    /// Add a response header which will be sent to the client.
    func writeHeaderLine(h: String) {}
    /// Send header bytes to the client.
    func writeHeaderBytes(b: [UInt8]) {}
    /// Write body bytes ot the client. Any pending header data will be written first.
    func writeBodyBytes(b: [UInt8]) {}
}

public class HTTP2WebRequest: WebRequest {

}

public class HTTP2WebResponse: WebResponse, HeaderListener {
    public func addHeader(name: [UInt8], value: [UInt8], sensitive: Bool) {
        let n = UTF8Encoding.encode(name)
        let v = UTF8Encoding.encode(value)
        
        switch n {
        case ":status":
            self.setStatus(Int(v) ?? -1, message: "")
        default:
            headersArray.append((n, v))
        }
    }
}

public class HTTP2Client {
    enum StreamState {
        case None, Idle, ReservedLocal, ReservedRemote, Open, HalfClosedRemote, HalfClosedLocal, Closed
    }
    
    let net = NetTCPSSL()
    var host = ""
    var timeoutSeconds = 5.0
    var ssl = true
    var streams = [UInt32: StreamState]()
    var streamCounter = UInt32(1)
    
    var encoder = HPACKEncoder()
    
    let closeLock = Threading.Lock()
    
    let frameReadEvent = Threading.Event()
    var frameQueue = [HTTP2Frame]()
    var frameReadOk = false
    
    var newStreamId: UInt32 {
        streams[streamCounter] = .None
        let s = streamCounter
        streamCounter += 2
        return s
    }
    
    public init() {}
    
    func dequeueFrame(timeoutSeconds: Double) -> HTTP2Frame? {
        var frame: HTTP2Frame? = nil
        
        self.frameReadEvent.doWithLock {
            [unowned self] in
            if self.frameQueue.count == 0 {
                self.frameReadEvent.wait(Int(timeoutSeconds * 1000.0))
            }
            if self.frameQueue.count > 0 {
                frame = self.frameQueue.removeFirst()
            }
        }
        return frame
    }
    
    func dqueueFrame(timeoutSeconds: Double, streamId: UInt32) -> HTTP2Frame? {
        var frame: HTTP2Frame?
        self.frameReadEvent.doWithLock {
            [unowned self] in
            if self.frameQueue.count == 0 {
                self.frameReadEvent.wait(Int(timeoutSeconds * 1000.0))
            }
            if self.frameQueue.count > 0 {
                for i in 0..<self.frameQueue.count {
                    let frameTest = self.frameQueue[i]
                    if frameTest.streamId == streamId {
                        self.frameQueue.removeAtIndex(i)
                        frame = frameTest
                        break
                    }
                }
            }
        }
        
        return frame
    }
    
    func processSettingsPayload(b: Bytes) {
        while b.availableExportBytes >= 6 {
            let identifier = ntohs(b.export16Bits())
//            let value = ntohl(b.export32Bits())
            
//            print("Setting \(identifier) \(value)")
            switch identifier {
            case SETTINGS_HEADER_TABLE_SIZE:
                ()//self.encoder = HPACKEncoder(maxCapacity: Int(value))
            case SETTINGS_ENABLE_PUSH:
                ()
            case SETTINGS_MAX_CONCURRENT_STREAMS:
                ()
            case SETTINGS_INITIAL_WINDOW_SIZE:
                ()
            case SETTINGS_MAX_FRAME_SIZE:
                ()
            case SETTINGS_MAX_HEADER_LIST_SIZE:
                ()
            default:
                ()
            }
        }
    }
    
    func readOneFrame() {
        Threading.dispatchBlock { 
            [unowned self] in
            self.readHTTP2Frame(-1) {
                [weak self] f in
                if let frame = f {
                    self?.frameReadEvent.doWithLock {
                        switch frame.type {
                        case HTTP2_SETTINGS:
                            let endStream = (frame.flags & HTTP2_SETTINGS_ACK) != 0
                            if !endStream {
                                // ACK settings receipt
                                if let payload = frame.payload {
                                    self?.processSettingsPayload(Bytes(existingBytes: payload))
                                }
                                let response = HTTP2Frame(length: 0, type: HTTP2_SETTINGS, flags: HTTP2_SETTINGS_ACK, streamId: 0, payload: nil)
                                self?.writeHTTP2Frame(response) {
                                        b in
                                    self?.readOneFrame()
                                }
                            }
                            else {
                                // Ack of our settings frame
                                self?.readOneFrame()
                            }
                            
                        case HTTP2_PING:
                            let endStream = (frame.flags & HTTP2_PING_ACK) != 0
                            if !endStream {
                                // ack ping receipt
                                if let payload = frame.payload {
                                    self?.processSettingsPayload(Bytes(existingBytes: payload))
                                }
                                let response = HTTP2Frame(length: frame.length, type: HTTP2_PING, flags: HTTP2_PING_ACK, streamId: 0, payload: frame.payload)
                                self?.writeHTTP2Frame(response) {
                                    b in
                                    self?.readOneFrame()
                                }
                            }
                            else {
                                // ack of our ping frame
                                self?.readOneFrame()
                            }
                            
                        default:
                            self?.frameQueue.append(frame)
                            self?.frameReadOk = true
                            self?.frameReadEvent.broadcast()
                        }
                    }
                }
                else {
                    // network error
                    self?.frameReadEvent.doWithLock {
                        self?.close()
                        self?.frameReadOk = false
                        self?.frameReadEvent.broadcast()
                    }
                }
            }
        }
    }
    
    func startReadThread() {
        Threading.dispatchBlock { 
            [weak self] in
            // dbg
            defer { print("~HTTP2Client.startReadThread") }
            if let net = self?.net {
                while net.fd.isValid {
                    if let s = self {
                        s.frameReadEvent.doWithLock({ 
                            s.frameReadOk = false
                            s.readOneFrame()
                            if !s.frameReadOk && net.fd.isValid {
                                s.frameReadEvent.wait()
                            }
                        })
                        if !s.frameReadOk {
                            s.close()
                            break
                        }
                    }
                    else {
                        net.close()
                        break
                    }
                }
            }
        }
    }
    
    public func close() {
        self.closeLock.doWithLock { 
            [unowned self] in
            self.net.close()
        }
    }
    
    public var isConnected: Bool {
        return self.net.fd.isValid
    }
    
    public func connect(host: String, port: UInt16, ssl: Bool, timeoutSceonds: Double, callback: (Bool) -> Void) {
        self.host = host
        self.ssl = ssl
        self.timeoutSeconds = timeoutSeconds
        
        do {
            try net.connect(host, port: port, timeoutSeconds: timeoutSeconds) {
                n in
                if let net = n as? NetTCPSSL {
                    if ssl {
                        net.beginSSL {
                            b in
                            if b {
                                self.completeConntect(callback)
                            }
                            else {
                                callback(false)
                            }
                        }
                    }
                    else {
                        self.completeConntect(callback)
                    }
                }
                else {
                    callback(false)
                }
            }
        } catch {
            callback(false)
        }
    }
    func completeConntect(callback: (Bool) -> ()) {
        net.writeString("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n") { (wrote) in
            let settings = HTTP2Frame(length: 0, type: HTTP2_SETTINGS, flags: 0, streamId: 0, payload: nil)
            self.writeHTTP2Frame(settings, callback: { [weak self] (b) in
                if b {
                    self?.startReadThread()
                }
                callback(b)
            })
        }
    }
    
    public func createRequest() -> HTTP2WebRequest {
        return HTTP2WebRequest(HTTP2Connection(client: self))
    }
    
    func awaitResponse(streamId: UInt32, request: WebRequest, callback: (WebResponse?, String?) -> ()) {
        
    }
    
    func bytesToHeader(b: [UInt8]) -> HTTP2Frame {
        let payloadLength = (UInt32(b[0]) << 16) + (UInt32(b[1]) << 8) + UInt32(b[2])
        
        let type = b[3]
        let flags = b[4]
        var sid: UInt32 = UInt32(b[5])
        sid << 8
        sid += UInt32(b[6])
        sid << 8
        sid += UInt32(b[7])
        sid << 8
        sid += UInt32(b[8])
        
        sid &= ~0x80000000
        
        return HTTP2Frame(length: payloadLength, type: type, flags: flags, streamId: sid, payload: nil)
    }
    
    func readHTTP2Frame(timeout: Double, callback: (HTTP2Frame?) -> ()) {
        let net = self.net
        net.readBytesFully(9, timeoutSecondes: timeout) {
            bytes in
            if let b = bytes {
                var header = self.bytesToHeader(b)
                if header.length > 0 {
                    net.readBytesFully(Int(header.length), timeoutSecondes: timeout, completion: { (bytes) in
                        header.payload = bytes
                        callback(header)
                    })
                }
                else {
                    callback(header)
                }
            }
            else {
                callback(nil)
            }
        }
    }
    
    func writeHTTP2Frame(frame: HTTP2Frame, callback: (Bool) -> ()) {
        if !net.fd.isValid {
            callback(false)
        }
        else if !net.writeBytesFully(frame.headerBytes()) {
            callback(false)
        }
        else {
            if let p = frame.payload {
                callback(net.writeBytesFully(p))
            }
            else {
                callback(true)
            }
        }
    }
    
    func encodeHeaders(headers: [(String, String)]) -> Bytes {
        let b = Bytes()
        let encoder = HPACKEncoder(maxCapacity: 4096)
        for header in headers {
            let n = UTF8Encoding.decode(header.0)
            let v = UTF8Encoding.decode(header.1)
            do {
                try encoder.encodeHeader(b, name: n, value: v, sensitive: false)
            } catch {
                self.close()
                break;
            }
        }
        return b
    }
    
    func decodeHeaders(from: Bytes, endPosition: Int, listener: HeaderListener) {
        let decoder = HPACKDecoder()
        do {
            try decoder.decode(from, headerListener: listener)
        } catch {
            self.close()
        }
    }
}
