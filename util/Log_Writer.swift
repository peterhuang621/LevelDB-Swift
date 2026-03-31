//
//  Log_Writer.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/1.
//

import Foundation

fileprivate func InitTypeCrc(_ type_crc: UnsafeMutablePointer<UInt32>) {
    for i in 0 ... kMaxRecordType {
        var t = UInt8(i)
        type_crc.advanced(by: i).pointee = Value(&t, 1)
    }
}

public class Writer {
    // MARK: - Private properties and initializers

    private var dest_: WritableFile?
    private var block_offset_: Int
    private var type_crc_: [UInt32] = Array(repeating: 0, count: kMaxRecordType + 1)

    init(dest: WritableFile?, dest_length: Int) {
        dest_ = dest
        block_offset_ = dest_length % kBlockSize
        type_crc_.withUnsafeMutableBufferPointer {
            InitTypeCrc($0.baseAddress!)
        }
    }

    init(dest: WritableFile?) {
        dest_ = dest
        block_offset_ = 0
        type_crc_.withUnsafeMutableBufferPointer {
            InitTypeCrc($0.baseAddress!)
        }
    }

//    private func EmitPhysicalRecord(_ type: RecordType, _ ptr: UnsafePointer<UInt8>, _ length: Int) -> Status {
//    }

//    public func AddRecord(_ slice: Slice) -> Status {
//    }
}
