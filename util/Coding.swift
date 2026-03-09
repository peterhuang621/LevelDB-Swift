//
//  Coding.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

func DecodeFixed32(_ ptr: UnsafePointer<UInt8>) -> UInt32 {
    return UInt32(ptr[0]) | (UInt32(ptr[1]) << 8) | (UInt32(ptr[2]) << 16) | (UInt32(ptr[3]) << 24)
}
