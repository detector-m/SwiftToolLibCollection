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
    /// !FIX! needs to pull key from possible request param
    func getSessionKey(name: String) -> String {
        // ...
        for (cName, cValue) in self.request.cookies {
            if name == cName {
                return cValue
            }
        }
        return SessionManager.generateSessionKey()
    }
    
    /// Provides access to the indicated `SessionManager` object.
    /// If the session does not exist it is created. if it does exist, the existing o bject is returned.
    public func getSession(named: String) -> SessionManager {
        if let s = self.sessions[named] {
            return s
        }
        let s = SessionManager(SessionConfiguration(named, id: getSessionKey(perfectSessionNamePrefix + named)))
        self.sessions[named] = s
        
        return s
    }
    
    /// Provides access to the indicated `SessionManager` object using the given `SessionConfiguration` data.
    /// - throws: If the session already exists, `PerfectError.APIError` is thrown.
    public func getSession(named: String, withConfiguration: SessionConfiguration) throws -> SessionManager {
        guard self.sessions[named] == nil
            else {
                throw PerfectError.APIError("WebResponse getSession withConfiguration: session was already initialized")
        }
        let s = SessionManager(SessionConfiguration(named, id:getSessionKey(perfectSessionNamePrefix + named), copyFrom: withConfiguration))
        self.sessions[named] = s
        return s
    }
    
    /// Discards a previously started session. The session will not be propagated and any changes to the session's variables will be discarded.
    public func abandonSession(named: String) {
        do {
            try self.sessions[named]?.abandon()
        } catch let e {
            LogManager.logMessage("Exception while abandoning session \(named) \(e)")
        }
        self.sessions.removeValueForKey(named)
    }
    
    // MARK: -
    /// Perform a 302 redirect to the given url
    public func redirectTo(url: String) {
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
    
    // Directly called by the websockets impl
    func sendResponse() {
        for (key, value) in headersArray {
            connection.writeHeaderLine(key + ":" + value)
        }
        // cookies
        if self.cookiesArray.count > 0 {
            let standardDateFormat = "';expires='E, dd-LLL-yyyy HH:mm:ss 'GMT'"
            let now = ICU.getNow()
            for cookie in self.cookiesArray {
                var cookieLine = "Set-Cookie: "
                cookieLine.appendContentsOf(cookie.name!.stringByEncodingURL)
                cookieLine.appendContentsOf("=")
                cookieLine.appendContentsOf(cookie.value!.stringByEncodingURL)
                if cookie.expiresIn != 0.0 {
                    let formattedDate = try! ICU.formatDate(now + ICU.secondsToICUDate(Int(cookie.expiresIn) * 60), format: standardDateFormat, timezone: "GMT")
                    cookieLine.appendContentsOf(formattedDate)
                }
                if let path = cookie.path {
                    cookieLine.appendContentsOf(";path=" + path)
                }
                if let domain = cookie.domain {
                    cookieLine.appendContentsOf(";domain=" + domain)
                }
                if let secure = cookie.secure {
                    if secure == true {
                        cookieLine.appendContentsOf(";secure")
                    }
                }
                if let httpOnly = cookie.httpOnly {
                    if httpOnly == true {
                        cookieLine.appendContentsOf("; HttpOnly")
                    }
                }
                // etc...
                connection.writeHeaderLine(cookieLine)
            }
        }
        connection.writeHeaderLine("Content-Length: \(bodyData.count)")
        connection.writeBodyBytes(bodyData)
    }
    
    private func doMainBody() {
        do {
            return
        } catch {
        
        }
    }
    
    func doSessionHeaders() {
        for (_, session) in self.sessions {
            session.initializeForResponse(self)
        }
    }
    func commitSessions() {
        for (name, session) in self.sessions {
            do {
                try session.commit()
            } catch let e {
                LogManager.logMessage("Exception while committing session \(name) \(e)")
            }
        }
    }
    
    func includeVirtual(path: String) throws {
        guard let handler = 
    }
}
