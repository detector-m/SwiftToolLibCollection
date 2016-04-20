//
//  Net.swift
//  PerfectLib
//
//  Created by Riven on 16/4/19.
//  Copyright © 2016年 Riven. All rights reserved.
//

import LibEvent

#if os(Linux)
#else
let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
let htons = isLittleEndian ? _OSSwapInt16 : { $0 }
let htonl = isLittleEndian ? _OSSwapInt32 : { $0 }
let htonll = isLittleEndian ? _OSSwapInt64 : { $0 }
let ntohs = isLittleEndian ? _OSSwapInt16 : { $0 }
let ntohl = isLittleEndian ? _OSSwapInt32 : { $0 }
let ntohll = isLittleEndian ? _OSSwapInt64 : { $0 }
#endif

let invalidSocket = Int32(-1)

/// Combines a socket with its family type & provides some utilities required by the LibEvent sub-system
public struct SocketFileDescriptor {
    var fd: Int32, family: Int32
    var isValid: Bool { return self.fd != invalidSocket }
    
    init(fd: Int32, family: Int32 = AF_UNSPEC) {
        self.fd = fd
        self.family = family
    }
    
    func switchToNBIO() -> Void {
        if self.fd != invalidSocket {
            evutil_make_socket_nonblocking(fd)
            evutil_make_listen_socket_reuseable(fd)
        }
    }
}