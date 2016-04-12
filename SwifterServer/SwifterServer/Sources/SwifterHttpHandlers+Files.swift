//
//  SwifterHttpHandlers+Files.swift
//  SwifterServer
//
//  Created by Riven on 16/4/12.
//  Copyright © 2016年 Riven. All rights reserved.
//

import Foundation

extension SwifterHttpHandlers {
    public class func shareFilesFromDirectory(directoryPath: String) -> (SwifterHttpRequest -> SwifterHttpResponse) {
        return {
            r in
            guard let fileRelativePath = r.params.first
                else {
                    return .NotFound
            }
            let absolutePath = directoryPath + "/" + fileRelativePath.1
            guard let file = try? SwifterFile.openForReading(absolutePath)
                else {
                    return .NotFound
            }
            return .RAW(200, "OK", [:], {
                writer in
                var buffer = [UInt8](count: 64, repeatedValue: 0)
                while let count = try? file.read(&buffer) where count > 0 {
                    writer.write(buffer[0..<count])
                }
                file.close()
            })
        }
    }
    
    private static let rangePrefix = "bytes="
    public class func directory(dir: String) -> (SwifterHttpRequest -> SwifterHttpResponse) {
        return {
            r in
            guard let localPath = r.params.first
                else {
                    return SwifterHttpResponse.NotFound
            }
            let filesPath = dir + "/" + localPath.1
            guard let fileBody = NSData(contentsOfFile: filesPath)
                else {
                    return SwifterHttpResponse.NotFound
            }
            
            if let rangeHeader = r.headers["range"] {
                guard rangeHeader.hasPrefix(SwifterHttpHandlers.rangePrefix)
                    else {
                        return .BadRequest(.Text("Invalid value of 'Range' header: \(r.headers["range"])"))
                }
                #if os(Linux)
                    let rangeString = rangeHeader.substringFromIndex(SwifterHttpHandlers.rangePrefix.characters.count)
                #else
                    let rangeString = rangeHeader.substringFromIndex(rangeHeader.startIndex.advancedBy(SwifterHttpHandlers.rangePrefix.characters.count))
                #endif
                
                let rangeStringExploded = rangeString.split("-")
                guard rangeStringExploded.count == 2
                    else {
                        return .BadRequest(.Text("Invalid value of 'Range' header: \(r.headers["range"])"))
                }
                
                let startStr = rangeStringExploded[0]
                let endStr = rangeStringExploded[1]
                
                guard let start = Int(startStr), end = Int(endStr)
                    else {
                        var array = [UInt8](count: fileBody.length, repeatedValue: 0)
                        fileBody.getBytes(&array, length: fileBody.length)
                        return SwifterHttpResponse.RAW(200, "OK", nil, { $0.write(array) })
                }
                let chunkLength = end - start
                let chunkRange = NSRange(location: start, length: chunkLength + 1)
                guard chunkRange.location + chunkRange.length <= fileBody.length
                    else {
                        return SwifterHttpResponse.RAW(416, "Requested range not satisfiable", nil, nil)
                }
                
                let chunk = fileBody.subdataWithRange(chunkRange)
                let headers = ["Content-Range": "bytes \(startStr)-\(endStr)/\(fileBody.length)"]
                var content = [UInt8](count: chunk.length, repeatedValue: 0)
                chunk.getBytes(&content, length: chunk.length)
                return SwifterHttpResponse.RAW(206, "Partial Content", headers, { $0.write(content) })
            }
            else {
                var content = [UInt8](count: fileBody.length, repeatedValue: 0)
                fileBody.getBytes(&content, length: fileBody.length)
                return SwifterHttpResponse.RAW(200, "OK", nil, { $0.write(content) })
            }
        }
    }
    
    public static func directoryBrowser(dir: String) -> (SwifterHttpRequest -> SwifterHttpResponse) {
        return {
            r in
            guard let (_, value) = r.params.first
                else {
                    return SwifterHttpResponse.NotFound
            }
            
            let filePath = dir + "/" + value
            let fileManager = NSFileManager.defaultManager()
            var isDir: ObjCBool = false
            guard fileManager.fileExistsAtPath(filePath, isDirectory: &isDir)
                else {
                    return SwifterHttpResponse.NotFound
            }
            if isDir {
                do {
                    let files = try fileManager.contentsOfDirectoryAtPath(filePath)
                    var response = "<h3>\(filePath)</h3></br><table>"
                    response += files.map({ "<tr><td><ahref=\"\(r.path)/\($0)\">\($0)</a></td></tr>" }).joinWithSeparator("")
                    response += "</table>"
                    return SwifterHttpResponse.OK(.Html(response))
                } catch {
                    return SwifterHttpResponse.NotFound
                }
            }
            else {
                if let content = NSData(contentsOfFile: filePath) {
                    var array = [UInt8](count: content.length, repeatedValue: 0)
                    content.getBytes(&array, length: content.length)
                    return SwifterHttpResponse.RAW(200, "OK", nil, { $0.write(array) })
                }
                
                return SwifterHttpResponse.NotFound
            }
        }
    }
}