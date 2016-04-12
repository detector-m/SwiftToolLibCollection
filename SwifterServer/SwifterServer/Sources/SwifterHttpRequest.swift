//
//  SwifterHttpRequest.swift
//  SwifterServer
//
//  Created by Riven on 16/4/9.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

public class SwifterHttpRequest {
    public var path: String = ""
    public var queryParams: [(String, String)] = []
    public var method: String = ""
    public var headers: [String: String] = [:]
    public var body: [UInt8] = []
    public var address: String? = ""
    public var params: [String: String] = [:]
    
    public func parseUrlencodedForm() -> [(String, String)] {
        guard let contentTypeHeader = self.headers["content-type"]
            else {
                return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.split(";").map { $0.trim() }
        guard let contentType = contentTypeHeaderTokens.first where contentType == "application/x-www-form-urlencoded"
            else {
                return []
        }
        
        return String.fromUInt8(body).split("&").map {
            param -> (String, String) in
            let tokens = param.split("=")
            if let name = tokens.first, value = tokens.last where tokens.count == 2 {
                return (name.replace("+", " ").removePercentEncoding(), value.replace("+", " ").removePercentEncoding())
            }
            
            return ("", "")
        }
    }
    
    public struct MultiPart {
        public let headers: [String: String]
        public let body: [UInt8]
        public var name: String? {
            return valueFor("content-disposition", parameter: "name")?.unquote()
        }
        public var fileName: String? {
            return valueFor("content-disposition", parameter: "filename")?.unquote()
        }
        
        private func valueFor(headerName: String, parameter: String) -> String? {
            return headers.reduce([String]()) {
                (combined, header: (key: String, value: String)) -> [String] in
                guard header.key == headerName
                    else {
                        return combined
                }
                let headerValueParams = header.value.split(";").map { $0.trim() }
                return headerValueParams.reduce(combined, combine: { (results, token) -> [String] in
                    let parameterTokens = token.split(1, separator: "=")
                    if parameterTokens.first == parameter, let value = parameterTokens.last {
                        return results + [value]
                    }
                    return results
                })
            }.first
        }
    }
    
    public func parseMultiPartFormData() -> [MultiPart] {
        guard let contentTypeHeader = headers["content-type"]
            else {
                return []
        }
        let contentTypeHeaderTokens = contentTypeHeader.split(";").map {
            $0.trim()
        }
        guard let contentType = contentTypeHeaderTokens.first where contentType == "multipart/form-data"
            else {
                return []
        }
        var boundary: String? = nil
        contentTypeHeaderTokens.forEach {
            let tokens = $0.split("=")
            if let key = tokens.first where key == "boundary" && tokens.count == 2 {
                boundary = tokens.last
            }
        }
        if let boundary = boundary where boundary.utf8.count > 0 {
            return parseMultipartFormData(body, boundary: "--\(boundary)")
        }
        
        return []
    }
    
    private func parseMultipartFormData(data: [UInt8], boundary: String) -> [MultiPart] {
        var generator = data.generate()
        var result = [MultiPart]()
        while let part = nexMultiPart(&generator, boundary: boundary, isFirst: result.isEmpty) {
            result.append(part)
        }
        
        return result
    }
    private func nexMultiPart(inout generator: IndexingGenerator<[UInt8]>, boundary: String, isFirst: Bool) -> MultiPart? {
        if isFirst {
            guard nextMultiPartLine(&generator) == boundary
                else {
                    return nil
            }
        }
        else {
            nextMultiPartLine(&generator)
        }
    
        var headers = [String: String]()
        while let line = nextMultiPartLine(&generator) where !line.isEmpty {
            let tokens = line.split(":")
            if let name = tokens.first, value = tokens.last where tokens.count == 2 {
                headers[name.lowercaseString] = value.trim()
            }
        }
        guard let body = nextMultiPartBody(&generator, boundary: boundary)
            else {
                return nil
        }
        return MultiPart(headers: headers, body: body)
    }
    private func nextMultiPartLine(inout generator: IndexingGenerator<[UInt8]>) -> String? {
        var result = String()
        while let value = generator.next() {
            if value > SwifterHttpRequest.CR {
                result.append(Character(UnicodeScalar(value)))
            }
            if value == SwifterHttpRequest.NL {
                break
            }
        }
        return result
    }
    
    static let CR = UInt8(13)
    static let NL = UInt8(10)
    
    private func nextMultiPartBody(inout generator: IndexingGenerator<[UInt8]>, boundary: String) -> [UInt8]? {
        var body = [UInt8]()
        let boundaryArray = [UInt8](boundary.utf8)
        var matchOffset = 0
        while let x = generator.next() {
            matchOffset = (x == boundaryArray[matchOffset] ? matchOffset + 1 : 0)
            body.append(x)
            if matchOffset == boundaryArray.count {
                body.removeRange(Range<Int>(body.count - matchOffset ..< body.count))
                if body.last == SwifterHttpRequest.NL {
                    body.removeLast()
                    if body.last == SwifterHttpRequest.CR {
                        body.removeLast()
                    }
                }
                return body
            }
        }
        return nil
    }
}
