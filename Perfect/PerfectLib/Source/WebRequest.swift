//
//  WebRequest.swift
//  PerfectLib
//
//  Created by Riven on 16/4/22.
//  Copyright © 2016年 Riven. All rights reserved.
//

/// Provides access to all incoming request data. Handles the following tasks:
/// - Parsing the incoming HTTP request
/// - Providing access to all HTTP header & cookies
/// - Providing access to all meta headers which may have been added by the web server
/// - Providing access to GET &  POST arguments
/// - Providing access to any file upload data
/// - Establishing the document root, from which response files are loacated
///
/// Access to the current WebRequest object is generally provided through the corresponding WebResponse object

public class WebRequest {
    var connection: WebConnection
    public lazy var documentRoot: String = {
        var f = self.connection.requestParams["PERFECTSERVER_DOCUMENT_ROOT"]
        var root = ""
        if let r = f {
            root = r
        }
        else {
            f = self.connection.requestParams["DOCUMENT_ROOT"]
            if let r = f {
                root = r
            }
        }
        
        return root
    }()
    
    private var cachedHttpAuthorization: [String: String]? = nil
    /// variables set by the URL routing process
    public lazy var urlVariables = [String: String]()
    
    /// A `Dictionary` containing all HTTP header names and values 
    /// Only HTTP headers are included in the result. Any "meta" headers, i.e those provided by the web server, are discarded.
    public lazy var headers: [String: String] = {
        var d = [String: String]()
       
        for (key, value) in self.connection.requestParams {
            if key.hasPrefix("HTTP_") {
//                let utf16 = key.utf16
                let index = key.utf16.startIndex.advancedBy(5)
                let nKey = String(key.utf16.suffixFrom(index))!
                d[nKey.stringByReplacingString("_", withString: "-")] = value
            }
        }
        
        return d
    }()
    
    /// A tuple array containing each incoming cookie name/value pair
    public lazy var cookies: [(String, String)] = {
        var c = [(String, String)]()
        let rawCookie = self.httpCookie()
        let semiSplit = rawCookie.characters.split(";").map {
            String($0.filter { $0 != " " })
        }
        
        for cookiePair in semiSplit {
            let cookieSplit = cookiePair.characters.split("=", allowEmptySlices: true).map {
                String($0.filter { $0 != " " })
            }
            if cookieSplit.count == 2 {
                let name = cookieSplit[0].stringByDecodingURL
                let value = cookieSplit[1].stringByDecodingURL
                if let n = name {
                    c.append((n, value ?? ""))
                }
            }
        }
        
        return c
    }()
    
    /// A tuple array containing each GET/search/query parameter name/value pair
    public lazy var queryParams: [(String, String)] = {
        var c = [(String, String)]()
        let qs = self.queryString()
        let semiSplit = qs.characters.split("&").map {
            String($0)
        }
        for paramPair in semiSplit {
            let paramSplit = paramPair.characters.split("=", allowEmptySlices: true).map {
                String($0)
            }
            if paramSplit.count == 2 {
                let name = paramSplit[0].stringByDecodingURL
                let value = paramSplit[1].stringByDecodingURL
                if let n = name {
                    c.append((n, value ?? ""))
                }
            }
        }
        
        return c
    }()
    
    /// An array of `MimeReader.BodySpec` objects which provide access to each file which was uploaded
    public lazy var fileUploads: [MimeReader.BodySpec] = {
        var c = Array<MimeReader.BodySpec>()
        if let mime = self.connection.mimes {
            for body in mime.bodySpecs {
                if body.file != nil {
                    c.append(body)
                }
            }
        }
        return c
    }()
    
    /// Return the raw POST body as a byte array
    /// This is mainly useful when posting non-url-encoded and not-multipart form data
    /// For example, if the content-type were application/json you could use this function to get the raw JSON data as bytes
    public lazy var postBodyBytes: [UInt8] = {
        if let stdin = self.connection.stdin {
            return stdin
        }
        return [UInt8]()
    }()
    
    /// Return the raw POST body as a String 
    /// this is mainly useful when POSTing non-url-encoded and not-multipart form data 
    /// For example, if the content-type were application/json you could use this function to get the raw JSON data as a String
    public lazy var pastBodyString: String = {
        if let stdin = self.connection.stdin {
            let qs = UTF8Encoding.encode(stdin)
            return qs
        }
        return ""
    }()
    
    /// A tuple array containing each POST parameter name/value pair
    public lazy var postParams: [(String, String)] = {
        var c = [(String, String)]()
        if let mime = self.connection.mimes {
            for body in mime.bodySpecs {
                if body.file == nil {
                    c.append((body.fieldName, body.fieldValue))
                }
            }
        }
        else if let stdin = self.connection.stdin {
            let qs = UTF8Encoding.encode(stdin)
            let semiSplit = qs.characters.split("&").map {
                String($0)
            }
            for paramPair in semiSplit {
                let paramSplit = paramPair.characters.split("=", allowEmptySlices: true).map {
                    String($0)
                }
                if paramSplit.count == 2 {
                    let name = paramSplit[0].stringByReplacingString("+", withString: " ").stringByDecodingURL
                    let value = paramSplit[1].stringByReplacingString("+", withString: " ").stringByDecodingURL
                    if let n = name {
                        c.append((n, value ?? ""))
                    }
                }
            }
        }
        return c
    }()
    
    /// Returns the first GET or POST parameter with the given name
    public func param(name: String) -> String? {
        for p in self.queryParams where p.0 == name {
            return p.1
        }
        for p in self.postParams where p.0 == name {
            return p.1
        }
        return nil
    }
    
    /// Returns the first GET or POST parameter with the given name
    /// Returns the supplied default value if the parameter was not found
    public func param(name: String, defaultValue: String) -> String {
        for p in self.queryParams where p.0 == name {
            return p.1
        }
        for p in self.postParams where p.0 == name {
            return p.1
        }
        return defaultValue
    }
    
    /// Returns all GET or POST parameters with the given name
    public func params(named: String) -> [String]? {
        var a = [String]()
        for p in self.queryParams where p.0 == named {
            a.append(p.1)
        }
        for p in self.postParams where p.0 == named {
            a.append(p.1)
        }
        return a.count > 0 ? a : nil
    }
    
    /// Returns all GET or POST parameters
    public func params() -> [(String, String)]? {
        var a = [(String, String)]()
        for p in self.queryParams {
            a.append(p)
        }
        for p in self.postParams {
            a.append(p)
        }
        return a.count > 0 ? a : nil
    }
    
    /// Provides access to the HTTP_CONNECTION parameter.
    public func httpConnection() -> String {
        return self.connection.requestParams["HTTP_CONNECTION"] ?? ""
    }
    /// Provides access to the HTTP_COOKIE parameter
    public func httpCookie() -> String {
        return self.connection.requestParams["HTTP_COOKIE"] ?? ""
    }
    /// access to the http_host parameter.
    public func httpHost() -> String {
        return connection.requestParams["HTTP_HOST"] ?? ""
    }
    /// access to the HTTP_USER_AGENT parameter
    public func httpUserAgent() -> String {
        return connection.requestParams["HTTP_USER_AGENT"] ?? ""
    }
    /// provides access to the http_cache_control parameter
    public func httpCacheControl() -> String {
        return connection.requestParams["HTTP_CACHE_CONTROL"] ?? ""
    }
    /// Provides access to the HTTP_REFERER parameter
    public func httpReferer() -> String {
        return connection.requestParams["HTTP_REFERER"] ?? ""
    }
    /// Provides access to the HTTP_REFERER parameter but using the proper "referrer" spelling for pedants.
    public func httpReferrer() -> String {
        return connection.requestParams["HTTP_REFERER"] ?? ""
    }
    /// provides access to hte HTTP_ACCEPT parameter
    public func httpAccept() -> String {
        return connection.requestParams["HTTP_ACCEPT"] ?? ""
    }
    /// provides access to the HTTP_ACCEPT_ENCODING parameter.
    public func httpAcceptEncoding() -> String {
        return connection.requestParams["HTTP_ACCEPT_ENCODING"] ?? ""
    }
    /// Provedes access to the HTTP_ACCEPT_LANGUAGE parameter.
    public func httpAcceptLanguage() -> String {
        return connection.requestParams["HTTP_ACCEPT_LANGUAGE"] ?? ""
    }
    
    /// Provedes access to the HTTP_AUTHORIZATION with all elements having been parsed using the `String.parseAuthentication` extension function.
    public func httpAuthorization() -> [String: String] {
        guard cachedHttpAuthorization == nil
            else {
                return  cachedHttpAuthorization!
        }
        let auth = connection.requestParams["HTTP_AUTHORIZATION"] ?? connection.requestParams["Authorization"] ?? ""
        var ret = auth.parseAuthentication()
        if ret.count > 0 {
            ret["method"] = self.requestMethod()
        }
        self.cachedHttpAuthorization = ret
        return ret
    }
    
    /// Provedes access to the CONTENT_LENGTH parameter.
    public func contentLength() -> Int {
        return Int(connection.requestParams["CONTENT_LENGTH"] ?? "0") ?? 0
    }
    public func contentType() -> String {
        return connection.requestParams["CONTENT_TYPE"] ?? ""
    }
    public func path() -> String {
        return self.connection.requestParams["PATH"] ?? ""
    }
    public func pathTranslated() -> String {
        return self.connection.requestParams["PATH_TRANSLATED"] ?? ""
    }
    public func queryString() -> String {
        return self.connection.requestParams["QUERY_STRING"] ?? ""
    }
    public func remoteAddr() -> String {
        return self.connection.requestParams["REMOTE_ADDR"] ?? ""
    }
    public func remotePort() -> Int {
        return Int(self.connection.requestParams["REMOTE_PORT"] ?? "0") ?? 0
    }
    public func requestMethod() -> String {
        return self.connection.requestParams["REQUEST_METHOD"] ?? ""
    }
    public func requestURI() -> String {
        return self.connection.requestParams["REQUEST_URI"] ?? ""
    }
    public func scriptFilename() -> String {
        return self.connection.requestParams["SCRIPT_FILENAME"] ?? ""
    }
    public func scriptName() -> String {
        return self.connection.requestParams["SCRIPT_NAME"] ?? ""
    }
    public func scriptURI() -> String {
        return self.connection.requestParams["SCRIPT_URI"] ?? ""
    }
    public func scriptURL() -> String {
        return self.connection.requestParams["SCRIPT_URL"] ?? ""
    }
    public func serverAddr() -> String {
        return self.connection.requestParams["SERVER_ADDR"] ?? ""
    }
    public func serverAdmin() -> String {
        return self.connection.requestParams["SERVER_ADMIN"] ?? ""
    }
    public func serverName() -> String {
        return self.connection.requestParams["SERVER_NAME"] ?? ""
    }
    public func serverPort() -> Int {
        return Int(self.connection.requestParams["SERVER_PORT"] ?? "0") ?? 0
    }
    public func serverProtocol() -> String {
        return self.connection.requestParams["SERVER_PROTOCOL"] ?? ""
    }
    public func serverSignature() -> String {
        return self.connection.requestParams["SERVER_SIGNATURE"] ?? ""
    }
    public func serverSoftware() -> String {
        return self.connection.requestParams["SERVER_SOFTWARE"] ?? ""
    }
    public func pathInfo() -> String {
        return self.connection.requestParams["PATH_INFO"] ?? self.connection.requestParams["SCRIPT_NAME"] ?? ""
    }
    public func gatewayInterface() -> String {
        return self.connection.requestParams["GATEWAY_INTERFACE"] ?? ""
    }
    public func isHttps() -> Bool {
        return self.connection.requestParams["HTTPS"] ?? "" == "on"
    }
    public func header(named: String) -> String? {
        return self.headers[named.uppercaseString]
    }
    public func rawHeader(named: String) -> String? {
        return self.connection.requestParams[named]
    }
    public func raw() -> Dictionary<String, String> {
        return self.connection.requestParams
    }
    
    public func setRequestMethod(method: String) {
        self.connection.requestParams["REQUEST_METHOD"] = method
    }
    public func setRequestURI(uri: String) {
        self.connection.requestParams["REQUEST_URI"] = uri
    }
    
    // MARK: - Init
    internal init(_ c: WebConnection) {
        self.connection = c
    }
    
    private func extractField(from: String, named: String) -> String? {
        guard let range = from.rangeOf(named + "=")
            else {
                return nil
        }
        
        var currPos = range.endIndex
        var ret = ""
        let quoted = from[currPos] == "\""
        if quoted {
            currPos = currPos.successor()
            let tooFar = from.endIndex
            while currPos != tooFar {
                if from[currPos] == "\"" {
                    break
                }
                ret.append(from[currPos])
                currPos = currPos.successor()
            }
        }
        else {
            let tooFar = from.endIndex
            while currPos != tooFar {
                if from[currPos] == "," {
                    break
                }
                ret.append(from[currPos])
                currPos = currPos.successor()
            }
        }
        
        return ret
    }
}
