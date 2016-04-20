//
//  PerfectError.swift
//  PerfectLib
//
//  Created by Riven on 16/4/13.
//  Copyright © 2016年 Riven. All rights reserved.
//

#if os(Linux)
    import SwiftGlibc
    import LinuxBridge
    
    var errno: Int32 {
        return linux_errno()
    }
#else
    import Darwin
#endif

/// Some but not all of the exception types which may be thrown by the system
public enum PerfectError: ErrorType {
    case NetworkError(Int32, String)
    case FileError(Int32, String)
    case SystemError(Int32, String)
    case APIError(String)
}

@noreturn
func ThrowFileError() throws {
    let err = errno
    let msg = String.fromCString(strerror(err))!
    
    throw PerfectError.FileError(err, msg)
}

@noreturn
func ThrowSystemError() throws {
    let err = errno
    let msg = String.fromCString(strerror(err))!
    throw PerfectError.SystemError(err, msg)
}

@noreturn
func throwNetworkError() throws {
    let err = errno
    let msg = String.fromCString(strerror(err))!
    throw PerfectError.NetworkError(err, msg)
}
