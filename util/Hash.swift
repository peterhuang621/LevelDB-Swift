//
//  Hash.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/9.
//

import Foundation

public func Hash(_ data: UnsafePointer<UInt8>, _ n: Int, _ seed: UInt32) -> UInt32 {
    let m: UInt32 = 0xC6A4A793
    let r: UInt32 = 24
    let limit: UnsafePointer<UInt8> = data.advanced(by: n)
    var ptr: UnsafePointer<UInt8> = data
    // Use wrapping multiply so overflow follows the hash algorithm.
    var h: UInt32 = seed ^ (UInt32(n) &* m)

    while limit - ptr >= 4 {
        let w = DecodeFixed32(ptr)
        ptr += 4
        h &+= w
        h &*= m
        h ^= (h >> 16)
    }

    switch limit - ptr {
    case 3:
        h += UInt32(data[2]) << 16
        fallthrough
    case 2:
        h += UInt32(data[1]) << 8
        fallthrough
    case 1:
        h += UInt32(data[0])
        h = h &* m
        h ^= (h >> r)
    default:
        break
    }

    return h
}
