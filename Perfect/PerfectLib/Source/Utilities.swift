//
//  Utilities.swift
//  PerfectLib
//
//  Created by Riven on 16/4/13.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import LinuxBridge
#else
    import Darwin
#endif

// This class permits an UnsafeMutablePointer to be used as a GeneratorType
public struct GenerateFromPointer<T> : GeneratorType {
    public typealias Element = T
    
    var count = 0
    var pos = 0
    var from: UnsafeMutablePointer<T>
    
    public init(from: UnsafeMutablePointer<T>, count: Int) {
        self.from = from
        self.count = count
    }
    
    mutating public func next() -> Element? {
        guard count > 0
            else {
                return nil
        }
        self.count -= 1
        let result = self.from[self.pos]
        self.pos += 1
        return result
    }
}

// MARK: - A generalized 
// a generalized wrapper around the  Unicode codec operations.
public class Encoding {
    public static func encode<D: UnicodeCodecType, G: GeneratorType where G.Element == D.CodeUnit>(decoder: D, generator: G) -> String {
        var encodedString = ""
        var finished: Bool = false
        var mutableDecoder = decoder
        var mutableGenerator = generator
        repeat {
            let decodingResult = mutableDecoder.decode(&mutableGenerator)
            switch decodingResult {
            case .Result(let char):
                encodedString.append(char)
            case .EmptyInput:
                finished = true
            case .Error:
                finished = true
            }
        } while !finished

        return encodedString
    }
}

public class UTF16Encoding {
    public static func encode<G: GeneratorType where G.Element == UTF16.CodeUnit>(generator: G) -> String {
        return Encoding.encode(UTF16(), generator: generator)
    }
}

public class UTF8Encoding {
    public static func encode<G: GeneratorType where G.Element == UTF8.CodeUnit>(generator: G) -> String {
        return Encoding.encode(UTF8(), generator: generator)
    }
    
    public static func encode<S: SequenceType where S.Generator.Element == UTF8.CodeUnit>(bytes: S) -> String {
        return encode(bytes.generate())
    }
    
    public static func decode(str: String) -> [UInt8] {
        return [UInt8](str.utf8)
    }
}

extension UInt8 {
    private var shouldURLEncode: Bool {
        let cc = self
        return ( ( cc >= 128 )
            || ( cc < 33 )
            || ( cc >= 34  && cc < 38 )
            || ( ( cc > 59  && cc < 61) || cc == 62 || cc == 58)
            || ( ( cc >= 91  && cc < 95 ) || cc == 96 )
            || ( cc >= 123 && cc <= 126 )
            || self == 43 )
    }
    
    private var hexString: String {
        var s = ""
        let b = self >> 4
        s.append(UnicodeScalar(b > 9 ? b - 10 + 65 : b + 48))
        let b2 = self & 0x0f
        s.append(UnicodeScalar(b2 > 9 ? b2 - 10 + 65 : 48 + b2))
        
        return s
    }
}

extension String {
    // Returns the String with all special HTML characters encoded.
    public var stringByEncodingHTML: String {
        var ret = ""
        var g = self.unicodeScalars.generate()
        while let c = g.next() {
            if c < UnicodeScalar(0x0009) {
                ret.appendContentsOf("&#x")
                ret.append(UnicodeScalar(0x0030 + UInt32(c)))
                ret.appendContentsOf(";")
            }
            else if c == UnicodeScalar(0x0022) {
                ret.appendContentsOf("&quot;")
            }
            else if c == UnicodeScalar(0x0026) {
                ret.appendContentsOf("&amp;")
            }
            else if c == UnicodeScalar(0x0027) {
                ret.appendContentsOf("&#39;")
            }
            else if c == UnicodeScalar(0x003c) {
                ret.appendContentsOf("&lt;")
            }
            else if c == UnicodeScalar(0x003e) {
                ret.appendContentsOf("&gt;")
            }
            else if c > UnicodeScalar(126) {
                ret.appendContentsOf("&#\(UInt32(c));")
            }
            else {
                ret.append(c)
            }
        }
        
        return ret
    }
    
    /// Returns the String with all special URL characters encoded.
    public var stringByEncodingURL: String {
        var ret = ""
        var g = self.utf8.generate()
        while let c = g.next() {
            if c.shouldURLEncode {
                ret.append(UnicodeScalar(37))
                ret.appendContentsOf(c.hexString)
            }
            else {
                ret.append(UnicodeScalar(c))
            }
        }
        
        return ret
    }
    
    // Utility - not sure if it makes the most sense to have here or outside or elsewhere
    static func byteFromHexDigits(one c1v: UInt8, two c2v: UInt8) -> UInt8? {
        let capA: UInt8 = 65
        let capF: UInt8 = 70
        let lowA: UInt8 = 97
        let lowF: UInt8 = 102
        let zero: UInt8 = 48
        let nine: UInt8 = 57
        
        var newChar = UInt8(0)
        if c1v >= capA && c1v <= capF {
            newChar = c1v - capA + 10
        }
        else if c1v >= lowA && c1v <= lowF {
            newChar = c1v - lowA + 10
        }
        else if c1v >= zero && c1v <= nine {
            newChar = c1v - zero
        }
        else {
            return nil
        }
        
        newChar *= 16
        
        if c2v >= capA && c2v <= capF {
            newChar += c2v - capA + 10
        }
        else if c2v >= lowA && c2v <= lowF {
            newChar += c2v - lowA + 10
        }
        else if c2v >= zero && c2v <= nine {
            newChar += c2v - zero
        }
        else {
            return nil
        }
        return newChar
    }
    
    public var stringByDecodingURL: String? {
        let percent: UInt8 = 37
        let plus: UInt8 = 43
        let space: UInt8 = 32
        
        var bytesArray = [UInt8]()
        
        var g = self.utf8.generate()
        while let c = g.next() {
            if c == percent {
                guard let c1v = g.next()
                    else {
                        return nil
                }
                guard let c2v = g.next()
                    else {
                        return nil
                }
                
                guard let newChar = String.byteFromHexDigits(one: c1v, two: c2v)
                    else {
                        return nil
                }
                bytesArray.append(newChar)
            }
            else if c == plus {
                bytesArray.append(space)
            }
            else {
                bytesArray.append(c)
            }
        }
        
        return UTF8Encoding.encode(bytesArray)
    }
    
    public var decodeHex: [UInt8]? {
        var bytesArray = [UInt8]()
        var g = self.utf8.generate()
        while let c1v = g.next() {
            guard let c2v = g.next()
                else {
                    return nil
            }
            guard let newChar = String.byteFromHexDigits(one: c1v, two: c2v)
                else {
                    return nil
            }
            bytesArray.append(newChar)
        }
        return bytesArray
    }
}

extension String {
    /// Parse uuid string
    /// Results undefined if the string is not a valid UUID
    public func asUUID() -> uuid_t {
        let u = UnsafeMutablePointer<UInt8>.alloc(sizeof(uuid_t))
        defer {
            u.destroy()
            u.dealloc(sizeof(uuid_t))
        }
        uuid_parse(self, u)
        return uuid_t(u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15])
    }
    
    public static func fromUUID(uuid: uuid_t) -> String {
        let u = UnsafeMutablePointer<UInt8>.alloc(sizeof(uuid_t))
        let unu = UnsafeMutablePointer<Int8>.alloc(37) // as per spec. 36 + null
        defer {
            u.destroy(); u.dealloc(sizeof(uuid_t))
            unu.destroy(); unu.dealloc(37)
        }
        
        u[0] = uuid.0; u[1] = uuid.1; u[2] = uuid.2; u[3] = uuid.3; u[4] = uuid.4; u[5] = uuid.5; u[6] = uuid.6; u[7] = uuid.7
        u[8] = uuid.8; u[9] = uuid.9; u[10] = uuid.10; u[11] = uuid.11; u[12] = uuid.12; u[13] = uuid.13; u[14] = uuid.14; u[15] = uuid.15
        uuid_unparse_lower(u, unu)
        
        return String.fromCString(unu)!
    }
}

public func empty_uuid() -> uuid_t {
    return uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

public func random_uuid() -> uuid_t {
    let u = UnsafeMutablePointer<UInt8>.alloc(sizeof(uuid_t))
    defer {
        u.destroy(); u.dealloc(sizeof(uuid_t))
    }
    
    uuid_generate_random(u)
    
    return uuid_t(u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15])
}

// MARK: - Parse an HTTP Digest authentication
extension String {
    /// Parse an HTTP Digest authentication header returning a Dictionary containing each part.
    public func parseAuthentication() -> [String: String] {
        var ret = [String: String]()
        if let _ = self.rangeOf("Digest ") {
            ret["type"] = "Digest"
            let wantFields = ["username", "nonce", "nc", "cnonce", "response", "uri", "realm", "qop", "algorithm"]
            for field in wantFields {
                if let foundField = String.extractField(self, named: field) {
                    ret[field] = foundField
                }
            }
        }
        return ret
    }
    
    private static func extractField(from: String, named: String) -> String? {
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

extension String {
    public func stringByReplacingString(find: String, withString: String) -> String {
        guard !find.isEmpty
            else {
                return self
        }
        guard !self.isEmpty else {
            return self
        }
        
        var ret = ""
        var idx = self.startIndex
        let endIdx = self.endIndex
        
        while idx != endIdx {
            if self[idx] == find[find.startIndex] {
                var newIdx = idx.advancedBy(1)
                var findIdx = find.startIndex.advancedBy(1)
                let findEndIdx = find.endIndex
                while newIdx != self.endIndex && findIdx != findEndIdx && self[newIdx] == find[findIdx] {
                    newIdx = newIdx.advancedBy(1)
                    findIdx = findIdx.advancedBy(1)
                }
                
                if findIdx == findEndIdx {
                    // match
                    ret.appendContentsOf(withString)
                    idx = newIdx
                    continue
                }
            }
            ret.append(self[idx])
            idx = idx.advancedBy(1)
        }
        return ret
    }
    
    public func substringTo(index: String.Index) -> String {
        var s = ""
        var idx = self.startIndex
        let endIdx = self.endIndex
        while idx != endIdx && idx != index {
            s.append(self[idx])
            idx = idx.successor()
        }
        
        return s
    }
    
    public func substringWith(range: Range<String.Index>) -> String {
        var s = ""
        var idx = range.startIndex
        let endIdx = self.endIndex
        while idx < endIdx && idx < range.endIndex {
            s.append(self[idx])
            idx = idx.successor()
        }
        
        return s
    }
    
    public func rangeOf(string: String, ignoreCase: Bool = false) -> Range<String.Index>? {
        var idx = self.startIndex
        let endIdx = self.endIndex
        
        while idx != endIdx {
            if ignoreCase ? (String(self[idx]).lowercaseString == String(string[string.startIndex]).lowercaseString) : (self[idx] == string[string.startIndex]) {
                var newIdx = idx.advancedBy(1)
                var findIdx = string.startIndex.advancedBy(1)
                let findEndIdx = string.endIndex
                
                while newIdx != self.endIndex && findIdx != findEndIdx && (ignoreCase ? (String(self[newIdx]).lowercaseString == String(string[findIdx]).lowercaseString) : (self[newIdx] == string[findIdx])) {
                    newIdx = newIdx.advancedBy(1)
                    findIdx = findIdx.advancedBy(1)
                }
                
                if findIdx == findEndIdx { // Match
                    return idx..<newIdx
                }
            }
            
            idx = idx.advancedBy(1)
        }
        return nil
    }
    
    public func contains(string: String) -> Bool {
        return nil != self.rangeOf(string)
    }
}

extension String {
    var pathSeparator: UnicodeScalar {
        return UnicodeScalar(47)
    }
    
    var extensionSeparator: UnicodeScalar {
        return UnicodeScalar(46)
    }
    
    private var beginsWithSeparator: Bool {
        let unis = self.characters
        guard unis.count > 0
            else {
                return false
        }
        return unis[unis.startIndex] == Character(pathSeparator)
    }
    
    private var endsWithSeparator: Bool {
        let unis = self.characters
        guard unis.count > 0
            else {
                return false
        }
        return unis[unis.endIndex.predecessor()] == Character(pathSeparator)
    }
    
    private func pathComponents(addFirstLast: Bool) -> [String] {
        var r = [String]()
        let unis = self.characters
        guard unis.count > 0
            else {
                return r
        }
        if addFirstLast && self.beginsWithSeparator {
            r.append(String(pathSeparator))
        }
        r.appendContentsOf(self.characters.split(Character(pathSeparator)).map { String($0) })
        
        if addFirstLast && self.endsWithSeparator {
            if !self.beginsWithSeparator || r.count > 1 {
                r.append(String(pathSeparator))
            }
        }
        
        return r
    }
    
    var pathComponents: [String] {
        return self.pathComponents(true)
    }
    
    var lastPathComponent: String {
        let last = self.pathComponents(false).last ?? ""
        if last.isEmpty && self.characters.first == Character(pathSeparator) {
            return String(pathSeparator)
        }
        return last
    }
    
    var stringByDeletingLastPathComponent: String {
        var comps = self.pathComponents(false)
        guard comps.count > 1
            else {
                if self.beginsWithSeparator {
                    return String(pathSeparator)
                }
                return ""
        }
        comps.removeLast()
        let joined = comps.joinWithSeparator(String(pathSeparator))
        if self.beginsWithSeparator {
            return String(pathSeparator) + joined
        }
        return joined
    }
    
    var stringByDeletingPathExtension: String {
        let unis = self.characters
        let startIndex = unis.startIndex
        var endIndex = unis.endIndex
        while endIndex != startIndex {
            if unis[endIndex.predecessor()] != Character(pathSeparator) {
                break
            }
            endIndex = endIndex.predecessor()
        }
        let noTrailsIndex = endIndex
        while endIndex != startIndex {
            endIndex = endIndex.predecessor()
            if unis[endIndex] == Character(extensionSeparator) {
                break
            }
        }
        guard endIndex != startIndex
            else {
                if noTrailsIndex == startIndex {
                    return self
                }
                return self.substringTo(noTrailsIndex)
        }
        
        return self.substringTo(endIndex)
    }
    
    var pathExtension: String {
        let unis = self.characters
        let startIndex = unis.startIndex
        var endIndex = unis.endIndex
        while endIndex != startIndex {
            if unis[endIndex.predecessor()] != Character(pathSeparator) {
                break
            }
            endIndex = endIndex.predecessor()
        }
        let noTrailsIndex = endIndex
        while endIndex != startIndex {
            endIndex = endIndex.predecessor()
            if unis[endIndex] == Character(extensionSeparator) {
                break
            }
        }
        guard endIndex != startIndex
            else {
                return ""
        }
        return self.substringWith(endIndex.successor()..<noTrailsIndex)
    }
    
    var stringByResolvingSymlinksInPath: String {
        return File(self).realPath()
        
//        		let absolute = self.beginsWithSeparator
//        		let components = self.pathComponents(false)
//        		var s = absolute ? "/" : ""
//        		for component in components {
//        			if component == "." {
//        				s.appendContentsOf(".")
//        			} else if component == ".." {
//        				s.appendContentsOf("..")
//        			} else {
//        				let file = File(s + "/" + component)
//        				s = file.realPath()
//        			}
//        		}
//        		let ary = s.pathComponents(false) // get rid of slash runs
//        		return absolute ? "/" + ary.joinWithSeparator(String(pathSeparator)) : ary.joinWithSeparator(String(pathSeparator))
    }
    
    #if os(Linux)
    func hasPrefix(of: String) -> Bool {
        let c1 = self.characters
        let c2 = of.characters
        return c1.count >= c2.count && String(c1.Prefix(c2.count)) == of
    }
    
    func hasSuffix(of: String) -> Bool {
        let c1 = self.characters
        let c2 = of.characters
        return c1.count >= c2.count && String(c1.suffix(c2.count)) == of
    }
    #endif
}
