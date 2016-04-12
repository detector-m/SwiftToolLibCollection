//
//  SwifterHttpParser.swift
//  SwifterServer
//
//  Created by Riven on 16/4/11.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

enum SwifterParserError: ErrorType {
    case InvalidStatusLine(String)
}

public class SwifterHttpParser {
    public init() {}
    
    public func readHttpRequest(socket: SwifterSocket) throws -> SwifterHttpRequest {
        let statusLine = try socket.readLine()
        let statusLineTokens = statusLine.split(" ")
        if statusLineTokens.count < 3 {
            throw SwifterParserError.InvalidStatusLine(statusLine)
        }
        let request = SwifterHttpRequest()
        request.method = statusLineTokens[0]
        request.path = statusLineTokens[1]
        request.queryParams = extractQueryParams(request.path)
        request.headers = try readHeaders(socket)
        if let contentLength = request.headers["content-length"], let contentLengthValue = Int(contentLength) {
            request.body = try readBody(socket, size: contentLengthValue)
        }
        
        return request
    }
    
    private func extractQueryParams(url: String) -> [(String, String)] {
        guard let query = url.split("?").last
            else {
                return []
        }
        return query.split("&").reduce([(String, String)]()) {
            (c, s) -> [(String, String)] in
            let tokens = s.split(1, separator: "=")
            if let name = tokens.first, value = tokens.last {
                return c + [(name.removePercentEncoding(), value.removePercentEncoding())]
            }
            
            return c
        }
    }
    
    private func readBody(socket: SwifterSocket, size: Int) throws -> [UInt8] {
        var body = [UInt8]()
        for _ in 0..<size {
            body.append(try socket.read())
        }
        
        return body
    }
    
    private func readHeaders(socket: SwifterSocket) throws -> [String: String] {
        var headers = [String: String]()
        repeat {
            let headerLine = try socket.readLine()
            if headerLine.isEmpty {
                return headers
            }
            let headerTokens = headerLine.split(1, separator: ":")
            if let name = headerTokens.first, value = headerTokens.last {
                headers[name.lowercaseString] = value.trim()
            }
            
        } while true
    }
    
    func supportsKeepAlive(headers: [String: String]) -> Bool {
        if let value = headers["connection"] {
            return "keep-alive" == value.trim()
        }
        
        return false
    }
}