//
//  StaticFileHandler.swift
//  PerfectLib
//
//  Created by Riven on 16/4/23.
//  Copyright © 2016年 Riven. All rights reserved.
//

public class StaticFileHandler: RequestHandler {
    public init() {}
    
    public func handleRequest(request: WebRequest, response: WebResponse) {
        var requestUri = request.requestURI()
        if requestUri.hasSuffix("/") {
            requestUri.appendContentsOf("index.html") // needs to be configurable
        }
        let documentRoot = request.documentRoot
        let file = File(documentRoot + "/" + requestUri)
        
        guard file.exists()
            else {
                response.setStatus(404, message: "not found")
                response.appendBodyString("The file \(requestUri) was not found.")
                // need 404.html or some such thing
                response.requestCompletedCallback()
                return
        }
        self.sendFile(response, file: file)
        response.requestCompletedCallback()
    }
    
    func sendFile(response: WebResponse, file: File) -> Void {
        defer {
            file.close()
        }
        let size = file.size()
        response.setStatus(200, message: "OK")
        do {
            let bytes = try file.readSomeBytes(size)
            response.addHeader("Content-type", value: MimeType.forExtension(file.path().pathExtension))
            response.appendBodyBytes(bytes)
        } catch {
            response.setStatus(500, message: "Internal server error")
        }
    }
}
