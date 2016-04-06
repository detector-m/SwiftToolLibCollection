//
//  PathKit.swift
//  SwiftToolLibCollection
//
//  Created by Riven on 16/4/6.
//  Copyright © 2016年 Riven. All rights reserved.
//

// PathKit - Effortless path operations

#if os (Linux)
    import Glibc
let system_glob = Glibc.glob
#else
    import Darwin
let system_glob = Darwin.glob
#endif

import Foundation

// MARK: - Represents a filesystem path.
public struct Path {
    // the character used by the os to separate two path elements
    public static let separator = "/"
    // underlying string representation
    var path: String
    static var fileManager = NSFileManager.defaultManager()
    
    // MARK: - Init
    public init() {
        path = ""
    }
    
    public init(_ path: String) {
        self.path = path
    }
    
    public init(path: String) {
        self.path = path
    }
    
    public init<S: CollectionType where S.Generator.Element == String>(components: S) {
        if components.isEmpty {
            path = "."
        }
        else if components.first == Path.separator && components.count > 1 {
            let p = components.joinWithSeparator(Path.separator)
            #if os(Linux)
            let index = p.startIndex.distanceTo(p.startIndex.successor())
            path = NSString(string: p).substringFromIndex(index)
            #else
            path = p.substringFromIndex(p.startIndex.successor())
            #endif
        }
        else {
            path = components.joinWithSeparator(Path.separator)
        }
    }
}

// MARK: - StringLiteralConvertible
extension Path: StringLiteralConvertible {
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    public typealias UnicodeScalarLiteralType = StringLiteralType
    
    public init(extendedGraphemeClusterLiteral path: StringLiteralType) {
        self.init(stringLiteral: path)
    }
    
    public init(unicodeScalarLiteral path: StringLiteralType) {
        self.init(stringLiteral: path)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        path = value
    }
}

// MARK: - CustomStringConvertible
extension Path: CustomStringConvertible {
    public var description: String {
        return path
    }
}

// MARK: - Hashable
extension Path: Hashable {
    public var hashValue: Int {
        return path.hashValue
    }
}

// MARK: Path Info
extension Path {
    public var isAbsolute: Bool {
        return path.hasPrefix(Path.separator)
    }
    
    public var isRelative: Bool {
        return !isAbsolute
    }
    
    public func absolute() -> Path {
        if isAbsolute {
            return normalize()
        }
        
        return (Path.current + self).normalize()
    }
    
    /// Normalizes the path, this cleans up redundant ".." and ".", double slashes
    /// and resolves "~".
    public func normalize() -> Path {
        return Path(path: NSString(string: path).stringByStandardizingPath)
    }
    
    public func abbreviate() -> Path {
        #if os(Linux)
            // TODO: actually de-normalize the path
            return self
        #else
            return Path(NSString(string: path).stringByAbbreviatingWithTildeInPath)
            
        #endif
    }
    
    // return the path of the item pointed to by a symbolic link
    public func symlinkDestination() throws -> Path {
        let symlinkDestination = try Path.fileManager.destinationOfSymbolicLinkAtPath(path)
        let symlinkPath = Path(symlinkDestination)
        if symlinkPath.isRelative {
            return self + ".." + symlinkPath
        }
        else {
            return symlinkPath
        }
    }
}

// MARK: - Path Components 
extension Path {
    // The last path component
    public var lastComponent: String {
        return NSString(string: path).lastPathComponent
    }
    
    public var lastComponentWithoutExtension: String {
        return NSString(string: lastComponent).stringByDeletingPathExtension
    }
    
    public var components: [String] {
        return NSString(string: path).pathComponents
    }
    
    public var `extension`: String? {
        let pathExtension = NSString(string: path).pathExtension
        if pathExtension.isEmpty {
            return nil
        }
        
        return pathExtension
    }
}

// MARK: File Info
extension Path {
    public var exists: Bool {
        return Path.fileManager.fileExistsAtPath(path)
    }
    
    public var isDirectory: Bool {
        var directory = ObjCBool(false)
        guard Path.fileManager.fileExistsAtPath(normalize().path, isDirectory: &directory)
            else {
                return false
        }
        
        return directory.boolValue
    }
    
    public var isFile: Bool {
        var directory = ObjCBool(false)
        guard Path.fileManager.fileExistsAtPath(normalize().path, isDirectory: &directory)
            else {
                return false
        }
        
        return !directory.boolValue
    }
    
    public var isSymlink: Bool {
        do {
            let _ = try Path.fileManager.destinationOfSymbolicLinkAtPath(path)
            return true
        }
        catch {
            return false
        }
    }
    
    public var isReadable: Bool {
        return Path.fileManager.isReadableFileAtPath(path)
    }
    
    public var isWritable: Bool {
        return Path.fileManager.isWritableFileAtPath(path)
    }
    
    public var isExecutable: Bool {
        return Path.fileManager.isExecutableFileAtPath(path)
    }
    
    public var isDeletable: Bool {
        return Path.fileManager.isDeletableFileAtPath(path)
    }
}

// MARK: - File Manipulation
extension Path {
    // Create the directory
    public func mkdir() throws -> () {
        return try Path.fileManager.createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
    }
    
    public func mkpath() throws -> () {
        return try Path.fileManager.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func delete() throws -> () {
        return try Path.fileManager.removeItemAtPath(path)
    }
    
    public func move(destination: Path) throws {
        return try Path.fileManager.moveItemAtPath(path, toPath: destination.path)
    }
    
    public func copy(destination: Path) throws -> () {
        try Path.fileManager.copyItemAtPath(path, toPath: destination.path)
    }
    
    // Creates a hard link at a new destination.
    public func link(destination: Path) throws -> () {
        try Path.fileManager.linkItemAtPath(path, toPath: destination.path)
    }
    
    // Creates a symbolic link at a new destination.
    public func symlink(destination: Path) throws -> () {
        try Path.fileManager.createSymbolicLinkAtPath(path, withDestinationPath: destination.path)
    }
}

// MARK: - Current Directory
extension Path {
    // The current working directory of the process 
    public static var current: Path {
        get {
            return self.init(Path.fileManager.currentDirectoryPath)
        }
        set {
            Path.fileManager.changeCurrentDirectoryPath(newValue.description)
        }
    }
    
    public func chdir(@noescape closure: () throws -> ()) rethrows {
        let previous = Path.current
        Path.current = self
        defer {
            Path.current = previous
        }
        try closure()
    }
}

// MARK: - Temporary
extension Path {
    public static var home: Path {
        #if os(Linux)
            return Path(NSProcessInfo.processInfo().environment["HOME"] ?? "/")
        #else
            return Path(NSHomeDirectory())
        #endif
    }
    
    public static var temporary: Path {
        #if os(Linux)
            return Path(NSProcessInfo.processInfo().environment["TMP"] ?? "/tmp")
        #else
            return Path(NSTemporaryDirectory())
        #endif
    }
    
    public static func processUniqueTemporary() throws -> Path {
        let path = temporary + NSProcessInfo.processInfo().globallyUniqueString
        if !path.exists {
            try path.mkdir()
        }
        
        return path
    }
    
    public static func uniqueTemporary() throws -> Path {
        let path = try processUniqueTemporary() + NSUUID().UUIDString
        try path.mkdir()
        return path
    }
}

// MARK: - Contents
extension Path {
    public func read() throws -> NSData {
        return try NSData(contentsOfFile: path, options: NSDataReadingOptions(rawValue: 0))
    }
    
    public func read(encoding: NSStringEncoding = NSUTF8StringEncoding) throws -> String {
        return try NSString(contentsOfFile: path, encoding: encoding).substringFromIndex(0) as String
    }
    
    public func write(data: NSData) throws {
        try data.writeToFile(normalize().path, options: .DataWritingAtomic)
    }
    
    public func write(string: String, encoding: NSStringEncoding = NSUTF8StringEncoding) throws {
        try NSString(string: string).writeToFile(normalize().path, atomically: true, encoding: encoding)
    }
}

// MARK: - Traversing
extension Path {
    public func parent() -> Path {
        return self + ".."
    }
    
    public func children() throws -> [Path] {
        return try Path.fileManager.contentsOfDirectoryAtPath(path).map {
            self + Path($0)
        }
    }
    
    public func recursiveChildren() throws -> [Path] {
        return try Path.fileManager.subpathsOfDirectoryAtPath(path).map {
            self + Path($0)
        }
    }
}

// MARK: - Globbing
extension Path {
    public static func glob(pattern: String) -> [Path] {
        var gt = glob_t()
        let cPattern = strdup(pattern)
        defer {
            globfree(&gt)
            free(cPattern)
        }
        
        let flags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK
        if system_glob(cPattern, flags, nil, &gt) == 0 {
            #if os(Linux)
                let matchc = gt.gl_pathc
            #else
                let matchc = gt.gl_matchc
            #endif
            
            return (0..<Int(matchc)).flatMap {
                index in
                if let path = String.fromCString(gt.gl_pathv[index]) {
                    return Path(path)
                }
                
                return nil
            }
        }
        
        // GLOB_NOMATCH
        return []
    }
    
    public func glob(pattern: String) -> [Path] {
        return Path.glob((self + pattern).description)
    }
}

// MARK: - SequenceType
extension Path: SequenceType {
    /// Enumerates the contents of a directory, returning the paths of all files and directories
    /// contained within that directory. These paths are relative to the directory.
    public struct DirectoryEnumerator: GeneratorType {
        public typealias Element = Path
        let path: Path
        let directoryEnumerator: NSDirectoryEnumerator
        
        init(path: Path) {
            self.path = path
            self.directoryEnumerator = Path.fileManager.enumeratorAtPath(path.path)!
        }
        
        public func next() -> DirectoryEnumerator.Element? {
            if let next = directoryEnumerator.nextObject() as? String? {
                return path + next!
            }
            
            return nil
        }
        
        public func skipDescendants() {
            directoryEnumerator.skipDescendants()
        }
    }
    
    /// Perform a deep enumeration of a directory.
    public func generate() -> Path.DirectoryEnumerator {
        return DirectoryEnumerator(path: self)
    }
}

// MARK: - Equaltable
extension Path: Equatable {}
public func ==(lhs: Path, rhs: Path) -> Bool {
    return lhs.path == rhs.path
}

// MARK: - Pattern Matching
public func ~=(lhs: Path, rhs: Path) -> Bool {
    return lhs == rhs || lhs.normalize() == rhs.normalize()
}

// MARK: - Comparable
extension Path: Comparable {}
public func <(lhs: Path, rhs: Path) -> Bool {
    return lhs.path < rhs.path
}

// MARK: - Operators
public func +(lhs: Path, rhs: Path) -> Path {
    return lhs.path + rhs.path
}

public func +(lhs: Path, rhs: String) -> Path {
    return lhs.path + rhs
}

private func +(lhs: String, rhs: String) -> Path {
    if rhs.hasPrefix(Path.separator) {
        return Path(rhs)
    }
    else {
        var lSlice = NSString(string: lhs).pathComponents.fullSlice
        var rSlice = NSString(string: rhs).pathComponents.fullSlice
        
        // Get rid of trailing "/" at the left side
        if lSlice.count > 1 && lSlice.last == Path.separator {
            lSlice.removeLast()
        }
        // Advance after the first relevant "."
        lSlice = lSlice.filter { $0 != "." }.fullSlice
        rSlice = rSlice.filter { $0 != "." }.fullSlice
        
        // Eats up trailing components of the left and leading ".." of the right side
        while lSlice.last != ".." && rSlice.first == ".." {
            if (lSlice.count > 1 || lSlice.first != Path.separator) && !lSlice.isEmpty {
                lSlice.removeLast()
            }
            if !rSlice.isEmpty {
                rSlice.removeFirst()
            }
            
            switch (lSlice.isEmpty, rSlice.isEmpty) {
            case (true, _):
                break
            case (_, true): break
            default:
                continue
            }
        }
        
        return Path(components: lSlice + rSlice)
    }
}

extension Array {
    var fullSlice: ArraySlice<Element> {
        return self[0..<self.endIndex]
    }
}
