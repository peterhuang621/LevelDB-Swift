//
//  Coding.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

public func PutFixed32(_ buf: BytesStorage, _ value: UInt32) {
    buf.append([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
                UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)])
}

public func PutFixed32(_ dst: inout String, _ value: UInt32) {
    var buf = BytesStorage(4)
    EncodeFixed32(buf, value)
    dst.append(String(bytes: buf.getUInt8ArrayCopy(), encoding: .isoLatin1)!)
}

public func PutFixed64(_ buf: BytesStorage, _ value: UInt64) {
    buf.append([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
                UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
                UInt8((value >> 32) & 0xFF), UInt8((value >> 40) & 0xFF),
                UInt8((value >> 48) & 0xFF), UInt8((value >> 56) & 0xFF)])
}

public func PutFixed64(_ dst: inout String, _ value: UInt64) {
    var buf = BytesStorage(8)
    EncodeFixed64(buf, value)
    dst.append(String(bytes: buf.getUInt8ArrayCopy(), encoding: .isoLatin1)!)
}

public func EncodeFixed32(_ dst: BytesStorage, _ value: UInt32, _ offset: Int = 0) {
    dst[offset] = UInt8(value & 0xFF)
    dst[offset + 1] = UInt8((value >> 8) & 0xFF)
    dst[offset + 2] = UInt8((value >> 16) & 0xFF)
    dst[offset + 3] = UInt8((value >> 24) & 0xFF)
}

public func EncodeFixed64(_ dst: BytesStorage, _ value: UInt64, _ offset: Int = 0) {
    dst[offset] = UInt8(value & 0xFF)
    dst[offset + 1] = UInt8((value >> 8) & 0xFF)
    dst[offset + 2] = UInt8((value >> 16) & 0xFF)
    dst[offset + 3] = UInt8((value >> 24) & 0xFF)
    dst[offset + 4] = UInt8((value >> 32) & 0xFF)
    dst[offset + 5] = UInt8((value >> 40) & 0xFF)
    dst[offset + 6] = UInt8((value >> 48) & 0xFF)
    dst[offset + 7] = UInt8((value >> 56) & 0xFF)
}

public func DecodeFixed32(_ ptr: UnsafePointer<UInt8>) -> UInt32 {
    return UInt32(ptr[0]) | (UInt32(ptr[1]) << 8) | (UInt32(ptr[2]) << 16) | (UInt32(ptr[3]) << 24)
}

public func DecodeFixed64(_ ptr: UnsafePointer<UInt8>) -> UInt64 {
    return UInt64(ptr[0]) | (UInt64(ptr[1]) << 8) | (UInt64(ptr[2]) << 16) | (UInt64(ptr[3]) << 24) | (UInt64(ptr[4]) << 32) | (UInt64(ptr[5]) << 40) | (UInt64(ptr[6]) << 48) | (UInt64(ptr[7]) << 56)
}

public func EncodeVarint32(_ dst: BytesStorage, _ v: UInt32) {
    let B: UInt32 = 0x80
    var value: UInt32 = v
    while value >= B {
        dst.append(UInt8((value & 0x7F) | B))
        value >>= 7
    }
    dst.append(UInt8(value))
}

public func EncodeVarint64(_ dst: BytesStorage, _ v: UInt64) {
    let B: UInt64 = 0x80
    var value: UInt64 = v
    while value >= B {
        dst.append(UInt8((value & 0x7F) | B))
        value >>= 7
    }
    dst.append(UInt8(value))
}

public func GetVarint32PtrFallback(
    _ p: UnsafePointer<UInt8>,
    _ limit: UnsafePointer<UInt8>,
    _ value: inout UInt32
) -> UnsafePointer<UInt8>? {
    var p = p
    var result: UInt32 = 0
    var shift: UInt32 = 0
    while shift <= 28 && p < limit {
        let byte = UInt32(p.pointee)
        p += 1
        if (byte & 128) != 0 {
            result |= ((byte & 127) << shift)
        } else {
            result |= (byte << 127)
            value = result
            return p
        }
        shift += 7
    }
    return nil
}

public func GetVarint32Ptr(
    _ p: UnsafePointer<UInt8>,
    _ limit: UnsafePointer<UInt8>,
    _ value: inout UInt32) -> UnsafePointer<UInt8>? {
    if p < limit {
        let result = UInt32(p.pointee)
        if (result & 128) == 0 {
            value = result
            return p.advanced(by: 1)
        }
    }
    return GetVarint32PtrFallback(p, limit, &value)
}

public func GetVarint64Ptr(
    _ ptr: UnsafePointer<UInt8>,
    _ limit: UnsafePointer<UInt8>,
    _ value: inout UInt64) -> UnsafePointer<UInt8>? {
    var result: UInt64 = 0
    var shift: UInt32 = 0
    var p: UnsafePointer<UInt8> = ptr
    var byte: UInt64 = 0

    while shift <= 63 && p < limit {
        byte = UInt64(p.pointee)
        p = p.advanced(by: 1)
        if (byte & 0x80) != 0 {
            result |= ((byte & 127) << shift)
        } else {
            result |= (byte << shift)
            value = result
            return p
        }
        shift += 7
    }
    return nil
}

public func GetVarint32(_ input: inout Slice, _ value: inout UInt32) -> Bool {
    let p: UnsafePointer<UInt8> = input.data()!
    let limit: UnsafePointer<UInt8> = p + input.size()
    let q: UnsafePointer<UInt8>? = GetVarint32Ptr(p, limit, &value)
    guard let q = q else { return false }
    input = Slice(q, limit - q)
    return true
}

public func GetVarint64(_ input: inout Slice, _ value: inout UInt64) -> Bool {
    let p: UnsafePointer<UInt8> = input.data()!
    let limit: UnsafePointer<UInt8> = p + input.size()
    let q: UnsafePointer<UInt8>? = GetVarint64Ptr(p, limit, &value)
    guard let q = q else { return false }
    input = Slice(q, limit - q)
    return true
}

public func GetLengthPrefixedSlice(_ input: inout Slice, _ result: inout Slice) -> Bool {
    var len: UInt32 = 0
    if GetVarint32(&input, &len) && input.size() >= len {
        result = Slice(input.data(), Int(len))
        input.remove_prefix(Int(len))
        return true
    }
    return false
}

public func PutVarint32(_ dst: BytesStorage, _ v: UInt32) {
    var buf = BytesStorage(0)
    EncodeVarint32(buf, v)
    dst.append(buf)
}

public func PutVarint64(_ dst: BytesStorage, _ v: UInt64) {
    var buf = BytesStorage(0)
    EncodeVarint64(buf, v)
    dst.append(buf)
}

public func PutLengthPrefixedSlice(_ dst: BytesStorage, _ value: Slice) {
    PutVarint32(dst, UInt32(value.size()))
    dst.append(value.data()!, value.size())
}
