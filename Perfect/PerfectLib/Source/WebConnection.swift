//
//  WebConnection.swift
//  PerfectLib
//
//  Created by Riven on 16/4/21.
//  Copyright © 2016年 Riven. All rights reserved.
//

/// This protocol represents a generalized web server connection
public protocol WebConnection {
    /// The TCP base connection
    var connection: NetTCP { get }
    /// The parameters sent by the client
    var requestParams: [String: String] { get set }
    /// Any non mime based request body data
    var stdin: [UInt8]? { get }
    /// Parsed mime based body data
    var mimes: MimeReader? { get }
    
    /// Set the response status code and message. for example, 200, "OK"
    func setStatus(code: Int, msg: String)
    /// Get the response status code and message.
    func getStatus() -> (Int, String)
    /// Add a response header which will be sent to the client.
    func writeHeaderLine(h: String)
    /// Send header bytes to the client.
    func writeHeaderBytes(b: [UInt8])
    /// Write body bytes to the client. Any pending header data will be written first
    func writeBodyBytes(b: [UInt8])
}
