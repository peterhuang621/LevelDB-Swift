//
//  Coding.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

public func PutFixed32(_ buf: inout [UInt8], _ value: UInt32) {
    buf.append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
                            UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)])
}

public func PutFixed32(_ dst: inout String, _ value: UInt32) {
    var buf = [UInt8](repeating: 0, count: 4)
    EncodeFixed32(dst: &buf, value: value)
    dst.append(String(bytes: buf, encoding: .isoLatin1)!)
}

public func PutFixed64(_ buf: inout [UInt8], _ value: UInt64) {
    buf.append(contentsOf: [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
                            UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
                            UInt8((value >> 32) & 0xFF), UInt8((value >> 40) & 0xFF),
                            UInt8((value >> 48) & 0xFF), UInt8((value >> 56) & 0xFF)])
}

public func PutFixed64(_ dst: inout String, _ value: UInt64) {
    var buf = [UInt8](repeating: 0, count: 8)
    EncodeFixed64(dst: &buf, value: value)
    dst.append(String(bytes: buf, encoding: .isoLatin1)!)
}

public func EncodeFixed32(dst: inout [UInt8], value: UInt32) {
    dst = [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
           UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
}

public func EncodeFixed32(dstData: inout Data, value: UInt32) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) {
        dstData.append(contentsOf: $0)
    }
}

public func EncodeFixed32(dst: inout [UInt8], offset: Int, value: UInt32) {
    dst[offset] = UInt8(value & 0xFF)
    dst[offset + 1] = UInt8((value >> 8) & 0xFF)
    dst[offset + 2] = UInt8((value >> 16) & 0xFF)
    dst[offset + 3] = UInt8((value >> 24) & 0xFF)
}

public func EncodeFixed64(dst: inout [UInt8], value: UInt64) {
    dst = [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF),
           UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF),
           UInt8((value >> 32) & 0xFF), UInt8((value >> 40) & 0xFF),
           UInt8((value >> 48) & 0xFF), UInt8((value >> 56) & 0xFF)]
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
public func EncodeVarint32(dstData: inout Data, _ v: UInt32) {
    let B: UInt32 = 0x80
    var value = v
    while value >= B {
        dstData.append(UInt8((value & 0x7F) | B))
        value >>= 7
    }
    dstData.append(UInt8(value))
}

public func EncodeVarint32(dstArray: inout [UInt8], _ v: UInt32) {
    let B: UInt32 = 0x80
    var value = v
    while value >= B {
        dstArray.append(UInt8((value & 0x7F) | B))
        value >>= 7
    }
    dstArray.append(UInt8(value))
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

public func GetVarint32(_ input: inout Slice, _ value: inout UInt32) -> Bool {
    return input.data().withUnsafeBytes {
        let p = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
        let limit = p.advanced(by: input.size())
        let q = GetVarint32Ptr(p, limit, &value)
        guard let q = q else { return false }
        input = Slice(q, limit - q)
        return true
    }
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

public func PutVarint32(_ dst: inout [UInt8], _ v: UInt32) {
    var buf: [UInt8] = []
    EncodeVarint32(dstArray: &buf, v)
    dst.append(contentsOf: buf)
}

public func PutLengthPrefixedSlice(_ dst: inout [UInt8], _ value: Slice) {
    PutVarint32(&dst, UInt32(value.size()))
    dst.append(contentsOf: value.data())
}
