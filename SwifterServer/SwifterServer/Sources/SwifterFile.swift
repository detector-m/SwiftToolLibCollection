//
//  SwifterFile.swift
//  SwifterServer
//
//  Created by Riven on 16/4/8.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

public enum SwifterFileError: ErrorType {
    case OpenFailed(String)
    case WriteFailed(String)
    case ReadFailed(String)
    case SeekFailed(String)
    case GetCurrentWorkingDirectoryFailed(String)
}

public class SwifterFile {
    private let pointer: UnsafeMutablePointer<FILE>
    public init(_ pointer: UnsafeMutablePointer<FILE>) {
        self.pointer = pointer
    }
    
    // MARK: - Current Working Directory
    public static func currentWorkingDirectory() throws -> String {
        let path = getcwd(nil, 0)
        if path == nil {
            throw SwifterFileError.GetCurrentWorkingDirectoryFailed(descriptionOfLastError())
        }
        guard let result = String.fromCString(path)
            else {
                throw SwifterFileError.GetCurrentWorkingDirectoryFailed("Could not convert getcwd(...)'s result to String.")
        }
        
        return result
    }
    
    // MARK: - Open
    public static func openNewForWriting(path: String) throws -> SwifterFile {
        return try openFileForMode(path, "wb")
    }
    public static func openForReading(path: String) throws -> SwifterFile {
        return try openFileForMode(path, "rb")
    }
    public static func openForWritingAndReading(path: String) throws -> SwifterFile {
        return try openFileForMode(path, "r+b")
    }
    
    public static func openFileForMode(path: String, _ mode: String) throws -> SwifterFile {
        let file = fopen(path.withCString {$0}, mode.withCString {$0})
        guard file != nil
            else {
                throw SwifterFileError.OpenFailed(descriptionOfLastError())
        }
        
        return SwifterFile(file)
    }
    
    // MARK: - Close
    public func close() -> Void {
        fclose(pointer)
    }
    
    // MARK: - Read
    public func read(inout data: [UInt8]) throws -> Int {
        if data.count <= 0 {
            return data.count
        }
        let count = fread(&data, 1, data.count, self.pointer)
        if count == data.count {
            return count
        }
        if feof(self.pointer) != 0 {
            return count
        }
        if ferror(self.pointer) != 0 {
            throw SwifterFileError.ReadFailed(SwifterFile.descriptionOfLastError())
        }
        throw SwifterFileError.ReadFailed("Unknown file read error occured.")
    }
    
    // MARK: - Write
    public func write(data: [UInt8]) throws {
        if data.count <= 0 {
            return ()
        }
        
        try data.withUnsafeBufferPointer({
            [unowned self] in
            if fwrite($0.baseAddress, 1, data.count, self.pointer) != data.count {
                throw SwifterFileError.WriteFailed(SwifterFile.descriptionOfLastError())
            }
        })
    }
    
    // MARK: - Seek
    public func seek(offset: Int) throws -> Void {
        if fseek(self.pointer, offset, SEEK_SET) != 0 {
            throw SwifterFileError.SeekFailed(SwifterFile.descriptionOfLastError())
        }
    }
    
    // MARK: - Private
    private static func descriptionOfLastError() -> String {
        return String.fromCString(UnsafePointer(strerror(errno))) ?? "Error: \(errno)"
    }
}

extension SwifterFile {
    public static func withNewFileOpenedForWriting<Result>(path: String, _ f: SwifterFile throws -> Result) throws -> Result {
        return try withFileOpenedForMode(path, mode: "wb", f)
    }
    
    public static func withFileOpenedForReading<Result>(path: String, _ f: SwifterFile throws -> Result) throws -> Result {
        return try withFileOpenedForMode(path, mode: "rb", f)
    }
    
    public static func withFileOpenedForWritingAndReading<Result>(path: String, _ f: SwifterFile throws -> Result) throws -> Result {
        return try withFileOpenedForMode(path, mode: "r+b", f)
    }


    
    public static func withFileOpenedForMode<Result>(path: String, mode: String, _ f: SwifterFile throws -> Result) throws -> Result {
        let file = try SwifterFile.openFileForMode(path, mode)
        defer {
            file.close()
        }
        
        return try f(file)
    }
}
