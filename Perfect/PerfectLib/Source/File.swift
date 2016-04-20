//
//  File.swift
//  PerfectLib
//
//  Created by Riven on 16/4/13.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import SwiftGlibc
    import LinuxBridge
    
    // !Fix! these are obviously sketchy
    // I hope SwiftGlibc to eventually include these
    // Otherwise, export them from LinuxBridge
    let S_IRGRP = (S_IRUSR >> 3)
    let S_IWGRP = (S_IWUSR >> 3)
    let S_IRWXU = (__S_IREAD|__S_IWRITE|__S_IEXEC)
    let S_IRWXG = (S_IRWXU >> 3)
    let S_IRWXO = (S_IRWXG >> 3)
    
    let SEEK_CUR: Int32 = 1
    let EXDEV = Int32(18)
    let EACCES = Int32(13)
    let EAGAIN = Int32(11)
    let F_OK: Int32 = 0
#else
    import Darwin
#endif

let fileCopyBufferSize = 16384

// Provides access to a file on the local file system
public class File: Closeable {
    var openMode = Int(O_RDONLY)
    var fd = -1
    var internalPath = ""
    
    public init(_ path: String, openMode: Int = Int(O_RDONLY)) {
        self.internalPath = path
        self.openMode = openMode
    }
    
    public init(fd: Int32, path: String = "") {
        self.fd = Int(fd)
        self.internalPath = path
    }
    
    public convenience init(tempFilePrefix: String) {
        let template = tempFilePrefix + "XXXXXX"
        let utf8 = template.utf8
        let name = UnsafeMutablePointer<Int8>.alloc(utf8.count + 1)
        var i = utf8.startIndex
        for index in 0..<utf8.count {
            name[index] = Int8(utf8[i])
            i = i.successor()
        }
        name[utf8.count] = 0
        
        let fd = mkstemp(name)
        let tmpFileName = String.fromCString(name)!
        name.dealloc(utf8.count + 1)
        name.destroy()
        
        self.init(fd: fd, path: tmpFileName)
    }
    
    // Return the file's path
    public func path() -> String {
        return internalPath
    }
    
    // returns the file path. if the file is a symbolic link, the link will be resolved
    public func realPath() -> String {
        if isLink() {
            let buffer = UnsafeMutablePointer<Int8>.alloc(2048)
            defer {
                buffer.destroy(); buffer.dealloc(2048)
            }
            let res = readlink(internalPath, buffer, 2048)
            if res != -1 {
                let ary = completeArray(buffer, count: res)
                let trailPath = UTF8Encoding.encode(ary)
                if trailPath[trailPath.startIndex] != "/" && trailPath[trailPath.startIndex] != "." {
                    return internalPath.stringByDeletingLastPathComponent + "/" + trailPath
                }
                return trailPath
            }
        }
        return internalPath
    }
    
    // MARK: - Delete
    public func delete() {
        if isOpen() {
            close()
        }
        unlink(path())
    }
    // MARK: - Close
    public func close() {
        if fd != -1 {
            #if os(Linux)
                SwiftGlibc.close(CInt(fd))
            #else
                Darwin.close(CInt(fd))
            #endif
            
            fd = -1
        }
    }
    // Resets the internal file descriptor, leaving the file opened if it had been.
    public func abandon() {
        fd = -1
    }
    
    // MARK: - Open
    public func open() throws {
        #if os(Linux)
            let openFd = linux_open(internalPath, CInt(openMode), mode_t(S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP))
        #else
            let openFd = Darwin.open(internalPath, CInt(openMode), mode_t(S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP))
        #endif
        guard openFd != -1
                else {
                try ThrowFileError()
        }
        fd = Int(openFd)
    }
    public func openRead() throws {
        openMode = Int(O_RDONLY)
        try open()
    }
    public func openWrite() throws {
        openMode = Int(O_RDWR|O_CREAT)
        try open()
    }
    public func openWriteOnly() throws {
        openMode = Int(O_WRONLY|O_CREAT)
        try open()
    }
    public func openAppend() throws {
        openMode = Int(O_RDWR|O_APPEND|O_CREAT)
        try open()
    }
    public func openTruncate() throws {
        openMode = Int(O_RDWR|O_TRUNC|O_CREAT)
        try open()
    }
    public func openRead(path: String) throws {
        internalPath = path
        try openRead()
    }
    public func openWrite(path: String) throws {
        internalPath = path
        try openWrite()
    }
    public func openWriteOnly(path: String) throws {
        internalPath = path
        try openWriteOnly()
    }
    public func openAppend(path: String) throws {
        internalPath = path
        try openAppend()
    }
    public func openTruncate(path: String) throws {
        internalPath = path
        try openTruncate()
    }
    
    // MARK: - File Position
    // Return the value of the file's current position marker
    public func marker() -> Int {
        if isOpen() {
            return Int(lseek(Int32(self.fd), 0, SEEK_CUR))
        }
        return 0
    }
    // Set the file's position marker given the `to` and `whence` parameters
    public func setMarker(to: Int, whence: Int32 = SEEK_CUR) -> Int {
        if isOpen() {
            return Int(lseek(Int32(self.fd), off_t(to), whence))
        }
        return 0
    }
    
    // MARK: - File modification
    public func modificationTime() -> Int {
        var st = stat()
        let res = isOpen() ? fstat(Int32(fd), &st) : stat(internalPath, &st)
        guard res == 0
            else {
                return Int.max
        }
        #if os(Linux)
            return Int(st.st_mtim.tv_sec)
        #else
            return Int(st.st_mtimespec.tv_sec)
        #endif
    }
    
    // MARK: - File move
    public func moveTo(path: String, overWrite: Bool = false) throws -> File {
        let destFile = File(path)
        if destFile.exists() {
            if overWrite {
                destFile.delete()
            }
            else {
                throw PerfectError.FileError(-1, "Can not overwrite existing file")
            }
        }
        close()
        let res = rename(self.path(), path)
        if res == 0 {
            return destFile
        }
        if errno == EXDEV {
            try self.copyTo(path, overWrite: overWrite)
            self.delete()
            return destFile
        }
        try ThrowFileError()
    }
    
    public func copyTo(path: String, overWrite: Bool = false) throws -> File {
        let destFile = File(path)
        if destFile.exists() {
            if overWrite {
                destFile.delete()
            }
            else {
                throw PerfectError.FileError(-1, "Can not overwrite existing file")
            }
        }
        let wasOpen = self.isOpen()
        let oldMarker = self.marker()
        if !wasOpen {
            try openRead()
        }
        else {
            setMarker(0)
        }
        defer {
            if !wasOpen {
                close()
            }
            else {
                setMarker(oldMarker)
            }
        }
        try destFile.openTruncate()
        var bytes = try self.readSomeBytes(fileCopyBufferSize)
        while bytes.count > 0 {
            try destFile.writeBytes(bytes)
            bytes = try self.readSomeBytes(fileCopyBufferSize)
        }
        destFile.close()
        return destFile
    }
    
    // MARK: - Is exists
    public func exists() -> Bool {
        return access(internalPath, F_OK) != -1
    }
    
    // MARK: - File size
    func sizeOr(value: Int) -> Int {
        var st = stat()
        let statRes = isOpen() ? fstat(Int32(fd), &st) : stat(internalPath, &st)
        guard statRes != -1
            else {
                return 0
        }
        if (Int32(st.st_mode) & Int32(S_IFMT)) == Int32(S_IFREG) {
            return Int(st.st_size)
        }
        return value
    }
    public func size() -> Int {
        var st = stat()
        let statRes = isOpen() ? fstat(Int32(fd), &st) : stat(internalPath, &st)
        guard statRes != -1
            else {
                return 0
        }
        return Int(st.st_size)
    }
    
    
    
    // MARK: - Is open
    public func isOpen() -> Bool {
        return fd != -1
    }
    // MARK: - Is a symblock link
    public func isLink() -> Bool {
        var st = stat()
        let statRes = lstat(internalPath, &st)
        guard statRes != -1
            else {
                return false
        }
        let mode = st.st_mode
        return (Int32(mode) & Int32(S_IFMT)) == Int32(S_IFLNK)
    }
    
    // MARK: - Is a directory
    public func isDir() -> Bool {
        var st = stat()
        let statRes = isOpen() ? fstat(Int32(fd), &st) : stat(internalPath, &st)
        guard statRes != -1
            else {
                return false
        }
        let mode = st.st_mode
        return (Int32(mode) & Int32(S_IFMT)) == Int32(S_IFDIR)
    }
    
    // Returns the UNIX style permissions for the file
    public func perms() -> Int {
        var st = stat()
        let statRes = isOpen() ? fstat(Int32(fd), &st) : stat(internalPath, &st)
        guard statRes != -1
            else {
                return 0
        }
        let mode = st.st_mode
        return Int(Int32(mode) ^ Int32(S_IFMT))
    }
    
    // MARK: - Read bytes
    // Read up to the indicated number of bytes from the fle
    public func readSomeBytes(count: Int) throws -> [UInt8] {
        if !isOpen() {
            try openRead()
        }
        let bSize = min(count, self.sizeOr(count))
        let ptr = UnsafeMutablePointer<UInt8>.alloc(bSize)
        defer {
            ptr.destroy()
            ptr.dealloc(bSize)
        }
        let readCount = read(CInt(fd), ptr, bSize)
        guard readCount >= 0
            else {
                try ThrowFileError()
        }
        return completeArray(ptr, count: readCount)
    }
    
    public func readString() throws -> String {
        let bytes = try self.readSomeBytes(self.size())
        return UTF8Encoding.encode(bytes)
    }
    
    public func writeBytes(bytes: [UInt8], dataPosition: Int, length: Int) throws -> Int {
        let ptr = UnsafeMutablePointer<UInt8>(bytes).advancedBy(dataPosition)
        let wrote = write(CInt(fd), ptr, length)
        guard wrote == length
            else {
                try ThrowFileError()
        }
        return wrote
    }
    public func writeBytes(bytes: [UInt8]) throws -> Int {
        return try writeBytes(bytes, dataPosition: 0, length: bytes.count)
    }
    
    public func writeString(s: String) throws -> Int {
        return try writeBytes(Array(s.utf8))
    }
    
    // MARK: - Lock
    // Attempts to place an advisory lock starting from the current position marker up to the indicated byte count. this function will block the current thread until the lock can be performed
    public func lock(byteCount: Int) throws {
        if !isOpen() {
            try openWrite()
        }
        let res = lockf(Int32(self.fd), F_LOCK, off_t(byteCount))
        guard res == 0
            else {
                try ThrowFileError()
        }
    }
    public func unlock(byteCount: Int) throws {
        if !isOpen() {
            try openWrite()
        }
        let res = lockf(Int32(self.fd), F_ULOCK, off_t(byteCount))
        guard res == 0
            else {
                try ThrowFileError()
        }
    }
    // Attempts to place an advisory lock starting from the current position marker up to the indicated byte count. This function will throw an exception if the file is already locked, but will not block the current thread.
    public func tryLock(byteCount: Int) throws {
        if !isOpen() {
            try openWrite()
        }
        let res = lockf(Int32(self.fd), F_TLOCK, off_t(byteCount))
        guard res == 0
            else {
                try ThrowFileError()
        }
    }
    
    // Tests if the indicated bytes are locked
    public func testLock(byteCount: Int) throws -> Bool {
        if !isOpen() {
            try openWrite()
        }
        let res = Int(lockf(Int32(self.fd), F_TEST, off_t(byteCount)))
        guard res == 0 || res == Int(EACCES) || res == Int(EAGAIN)
            else {
                try ThrowFileError()
        }
        return res != 0
    }
    
    // MARK: - Complete Array
    private func completeArray(from: UnsafeMutablePointer<UInt8>, count: Int) -> [UInt8] {
        defer {
            from.destroy()
        }
        var ary = [UInt8](count: count, repeatedValue: 0)
        for index in 0..<count {
            ary[index] = from[index]
        }
        return ary
    }
    private func completeArray(from: UnsafeMutablePointer<Int8>, count: Int) -> [UInt8] {
        defer {
            from.destroy()
        }
        var ary = [UInt8](count: count, repeatedValue: 0)
        for index in 0..<count {
            ary[index] = UInt8(from[index])
        }
        return ary
    }
}

class UnclosableFile: File {
    init(fd: Int32) {
        super.init(fd: fd, path: "")
    }
    
    override func close() {
        // TODO:
    }
}

// MARK: - Standard in
public func FileStding() -> File {
    return UnclosableFile(fd: STDIN_FILENO)
}
// standard out
public func FileStdout() -> File {
    return UnclosableFile(fd: STDOUT_FILENO)
}
// standard error
public func FileStderr() -> File {
    return UnclosableFile(fd: STDERR_FILENO)
}
