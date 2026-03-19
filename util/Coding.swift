//
//  Coding.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

public func PutFixed32(_ dst: inout String, _ value: UInt32) {
    var buf = [UInt8](repeating: 0, count: 4)
    EncodeFixed32(&buf, value)
    dst.append(String(decoding: buf, as: UTF8.self))
}

public func PutFixed64(_ dst: inout String, _ value: UInt64) {
    var buf = [UInt8](repeating: 0, count: 8)
    EncodeFixed64(&buf, value)
    dst.append(String(decoding: buf, as: UTF8.self))
}

public func EncodeFixed32(_ dst: inout [UInt8], _ value: UInt32) {
    dst = [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
           UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
}

public func EncodeFixed64(_ dst: inout [UInt8], _ value: UInt64) {
    dst = [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
           UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
           UInt8((value >> 32) & 0xFF), UInt8((value >> 40) & 0xFF),
           UInt8((value >> 48) & 0xFF), UInt8((value >> 56) & 0xFF)]
}

public func DecodeFixed32(_ ptr: UnsafePointer<UInt8>) -> UInt32 {
    return UInt32(ptr[0]) | (UInt32(ptr[1]) << 8) | (UInt32(ptr[2]) << 16) | (UInt32(ptr[3]) << 24)
}
