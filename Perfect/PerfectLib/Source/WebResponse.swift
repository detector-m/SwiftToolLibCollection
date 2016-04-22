//
//  WebResponse.swift
//  PerfectLib
//
//  Created by Riven on 16/4/22.
//  Copyright © 2016年 Riven. All rights reserved.
//

/// This class bundles together the values which will be used to set a cookie in the outgoing response
public struct Cookie {
    public let name: String?
    public let value: String?
    public let domain: String?
    public let expires: String?
    public let expiresIn: Double // seconds from now. may be negative. 0.0 means no expiry (session cookie)
    public let path: String?
    public let secure: Bool?
    public let httpOnly: Bool?
    
    public init(name: String?, value: String, domain: String?, expires: String?, expiresIn: Double, path: String?, secure: Bool?, httpOnly: Bool?) {
        self.name = name
        self.value = value
        self.domain = domain
        self.expires = expires
        self.expiresIn = expiresIn
        self.path = path
        self.secure = secure
        self.httpOnly = httpOnly
    }
}
/*
 class MustacheCacheItem {
	let modificationDate: Int
	let template: MustacheTemplate
	
	init(modificationDate: Int, template: MustacheTemplate) {
 self.modificationDate = modificationDate
 self.template = template
	}
 }
 
 let mustacheTemplateCache = RWLockCache<String, MustacheCacheItem>()
 */

/// Represents an outgoing web response. Handles the following tasks:
/// - Management of sessions
/// - Collecting HTTP response headers & cookies.
/// - Locating the response template file, parsing it evaluating it and returning the resulting data.
/// - Provides access to the WebRequest object.
public class WebResponse {
    var connection: WebConnection
    
    /// the WebReqeust for this response
    public var request: WebRequest
    
    /// the output encoding for a textual response. Defaults to UTF-8
    public var outputEncoding = "UTF-8"
    
    var headersArray = [(String, String)]()
    var cookiesArray = [Cookie]()
    var includeStatck = [String]()
    
    var appStatus = 0
    var appMessage = ""
    
    var bodyData = [UInt8]()
    
    var sessions = Dictionary<String, SessionManager>()
    
    public var requestCompletedCallback: () -> () = {}
    
    internal init(_ c: WebConnection, request: WebRequest) {
        self.connection = c
        self.request = request
    }
    
    /// Set the response status code and message. For example, 200, "OK"
    public func setStatus(code: Int, message: String) {
        self.connection.setStatus(code, msg: message)
    }
    /// Get the response status code and message.
    public func getStatus() -> (Int, String) {
        return self.connection.getStatus()
    }
    
    /// Adds the cookie object to the response
    public func addCookie(cookie: Cookie) {
        self.cookiesArray.append(cookie)
    }
    
    public func appendBodyBytes(bytes: [UInt8]) {
        self.bodyData.appendContentsOf(bytes)
    }
    
    public func appendBodyString(string: String) {
        self.bodyData.appendContentsOf([UInt8](string.utf8))
    }
    
    func respond(completion: () -> ()) -> Void {
        self.requestCompletedCallback = {
            [weak self] in
            self?
            
            completion()
        }
        doMainBody()
    }
    
    // MARK: - Session
    
    // MARK: -
    /// Perform a 302 redirect to the given url
    public func redirectTo(rul: String) {
        self.setStatus(302, message: "FOUND")
        self.replaceHeader("Location", value: url)
    }
    /// add an outgoing HTTP header
    public func addHeader(name: String, value: String) {
        self.headersArray.append((name, value))
    }
    /// Set a HTTP header, replacing all existing instances of said header
    public func replaceHeader(name: String, value: String) {
        for i in 0..<self.headersArray.count {
            if self.headersArray[i].0 == name {
                self.headersArray.removeAtIndex(i)
            }
        }
        self.addHeader(name, value: value)
    }
}
