//
//  Log_Format.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/26.
//

import Foundation

public enum RecordType: Int {
    // Zero is reserved for preallocated files
    case kZeroType = 0

    case kFullType

    // For fragments
    case kFirstType
    case kMiddleType
    case kLastType
}

public let kMaxRecordType: Int = RecordType.kLastType.rawValue

public let kBlockSize: Int = 32768

public let kHeaderSize: Int = 4 + 2 + 1
