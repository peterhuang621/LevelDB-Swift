//
//  Coding.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

public func PutFixed32(_ dst: inout String, _ value: UInt32) {
    var buf = [UInt8](repeating: 0, count: 4)
    EncodeFixed32(dst: &buf, value: value)
    dst.append(String(bytes: buf, encoding: .isoLatin1)!)
}

public func PutFixed64(_ dst: inout String, _ value: UInt64) {
    var buf = [UInt8](repeating: 0, count: 8)
    EncodeFixed64(dst: &buf, value: value)
    dst.append(String(bytes: buf, encoding: .isoLatin1)!)
}

public func EncodeFixed32(dst: inout [UInt8], value: UInt32) {
    dst = [UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
           UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)]
}

public func EncodeFixed32(dstData: inout Data, value: UInt32) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) {
        dstData.append(contentsOf: $0)
    }
}

public func EncodeFixed64(dst: inout [UInt8], value: UInt64) {
    dst = [UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
           UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff),
           UInt8((value >> 32) & 0xff), UInt8((value >> 40) & 0xff),
           UInt8((value >> 48) & 0xff), UInt8((value >> 56) & 0xff)]
}

public func EncodeFixed64(dstData: inout Data, value: UInt64) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) {
        dstData.append(contentsOf: $0)
    }
}

public func DecodeFixed32(_ ptr: UnsafePointer<UInt8>) -> UInt32 {
    return UInt32(ptr[0]) | (UInt32(ptr[1]) << 8) | (UInt32(ptr[2]) << 16) | (UInt32(ptr[3]) << 24)
}

public func DecodeFixed64(_ ptr: UnsafePointer<UInt8>) -> UInt64 {
    return UInt64(ptr[0]) | (UInt64(ptr[1]) << 8) | (UInt64(ptr[2]) << 16) | (UInt64(ptr[3]) << 24) | (UInt64(ptr[4]) << 32) | (UInt64(ptr[5]) << 40) | (UInt64(ptr[6]) << 48) | (UInt64(ptr[7]) << 56)
}

// In Swift, not recommend to return a pointer.
public func EncodeVarint32(_ dst: inout Data, _ v: UInt32) {
    let B: UInt32 = 0x80
    var value = v
    while value >= B {
        dst.append(UInt8((value & 0x7F) | B))
        value >>= 7
    }
    dst.append(UInt8(value))
}
