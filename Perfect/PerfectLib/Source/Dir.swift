//
//  Dir.swift
//  PerfectLib
//
//  Created by Riven on 16/4/13.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import SwiftGlibc
#else
    import Darwin
#endif

// This class represents a directory on the file system.
// It can be used for creating & inspecting directories and enumerating directory contents.
public class Dir {
    var internalPath = ""
    // Create a new Dir object with the given path 
    public init(_ path: String) {
        if path.hasSuffix("/") {
            self.internalPath = path
        }
        else {
            self.internalPath = path + "/"
        }
    }
    
    public func exists() -> Bool {
        return exists(realPath())
    }
    
    func exists(path: String) -> Bool {
        return access(path, F_OK) != -1
    }
    
    // MARK: - Creates
    public func create(perms: Int = Int(S_IRWXG|S_IRWXU|S_IRWXO)) throws {
        let pth = realPath()
        var currPath = pth.hasPrefix("/") ? "/" : ""
        for component in pth.pathComponents {
            if component != "/" {
                currPath += component
                if !exists(currPath) {
                    let res = mkdir(currPath, mode_t(perms))
                    guard res != -1
                        else {
                            try ThrowFileError()
                    }
                }
                currPath += "/"
            }
        }
    }
    
    public func delete() throws {
        let res = rmdir(realPath())
        guard res != -1
            else {
                try ThrowFileError()
        }
    }
    
    // Return the name of the directory
    public func name() -> String {
        return internalPath.lastPathComponent
    }
    
    // Returns a dir object representing the current dir's parent. Returns nil if there is no parent
    public func parentDir() -> Dir? {
        guard internalPath != "/"
            else {
                return nil // can not go up
        }
        return Dir(internalPath.stringByDeletingLastPathComponent)
    }
    
    // Returns the path to the current directory
    public func path() -> String {
        return internalPath
    }
    func realPath() -> String {
        return internalPath.stringByResolvingSymlinksInPath
    }
    
    // MARK: - Enumerates the contents
    // Enumerates the contents of the directory passing the name of each contained element to the provided callback.
    public func forEachEntry(closure: (name: String) -> ()) throws {
        let dir = opendir(realPath())
        guard dir != nil
            else {
                try ThrowFileError()
        }
        defer {
            closedir(dir)
        }
        
        var ent = dirent()
        let entPtr = UnsafeMutablePointer<UnsafeMutablePointer<dirent>>.alloc(1)
        defer {
            entPtr.destroy()
            entPtr.dealloc(1)
        }
        
        while readdir_r(dir, &ent, entPtr) == 0 && entPtr.memory != nil {
            let name = ent.d_name
            #if os(Linux)
                let nameLen = 1024
            #else
                let nameLen = ent.d_namlen
            #endif
            let type = ent.d_type
            
            var nameBuf = [CChar]()
            let mirror = Mirror(reflecting: name)
            let childGen = mirror.children.generate()
            for _ in 0..<nameLen {
                let (_, elem) = childGen.next()!
                if elem as! Int8 == 0 {
                    break
                }
                nameBuf.append(elem as! Int8)
            }
            nameBuf.append(0)
            if let name = String.fromCString(nameBuf) {
                if !(name == "." || name == "..") {
                    if Int32(type) == Int32(DT_DIR) {
                        closure(name: name + "/")
                    }
                    else {
                        closure(name: name)
                    }
                }
            }
        }
    }
}
