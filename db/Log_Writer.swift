//
//  Log_Writer.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/1.
//

import Foundation

fileprivate func InitTypeCrc(_ type_crc: UnsafeMutablePointer<UInt32>) {
    for i in 0 ... kMaxRecordType {
        var t: UInt8 = UInt8(i)
        type_crc.advanced(by: i).pointee = Value(&t, 1)
    }
}

public class Writer {
    // MARK: - Private properties, initializers and functions

    private var dest_: WritableFile
    private var block_offset_: Int
    private var type_crc_: [UInt32] = Array(repeating: 0, count: kMaxRecordType + 1)

    init(dest: WritableFile, dest_length: Int) {
        dest_ = dest
        block_offset_ = dest_length % kBlockSize
        type_crc_.withUnsafeMutableBufferPointer {
            InitTypeCrc($0.baseAddress!)
        }
    }

    init(dest: WritableFile) {
        dest_ = dest
        block_offset_ = 0
        type_crc_.withUnsafeMutableBufferPointer {
            InitTypeCrc($0.baseAddress!)
        }
    }

    private func EmitPhysicalRecord(_ t: RecordType, _ ptr: UnsafePointer<UInt8>, _ length: Int) -> Status {
        precondition(length <= 0xFFFF, "the length = \(length) must fit in two bytes")
        precondition(block_offset_ + kHeaderSize + length <= kBlockSize)

        let buf: BytesStorage = BytesStorage(kHeaderSize)
        buf[4] = UInt8(length & 0xFF)
        buf[5] = UInt8(length >> 8)
        buf[6] = UInt8(t.rawValue)

        var crc: UInt32 = Extend(type_crc_[Int(t.rawValue)], ptr, length)
        crc = Mask(crc)
        EncodeFixed32(buf, crc)

        var s = dest_.Append(Slice(buf, kHeaderSize))
        if s.ok() {
            s = dest_.Append(Slice(ptr, length))
            if s.ok() {
                s = dest_.Flush()
            }
        }
        block_offset_ += kHeaderSize + length
        return s
    }

    // MARK: - Public functions

    public func AddRecord(_ slice: Slice) -> Status {
        var ptr_ind: Int = 0
        let ptr: UnsafePointer<UInt8> = slice.data()!
        var left: Int = slice.size()

        var s: Status = Status()
        var begin: Bool = true
        repeat {
            let leftover = kBlockSize - block_offset_
            precondition(leftover >= 0, "leftover = \(leftover) should be equal or greater than 0")
            if leftover < kHeaderSize {
                precondition(kHeaderSize == 7, "kHeaderSize = \(kHeaderSize) should be equal to 7")
                let padding: BytesStorage = BytesStorage(leftover)
                _ = dest_.Append(Slice(padding, leftover))
            }
            block_offset_ = 0

            precondition(
                kBlockSize - block_offset_ - kHeaderSize >= 0,
                "error when doing calculations: kBlockSize = \(kBlockSize), block_offset_ = \(block_offset_), kHeaderSize = \(kHeaderSize)"
            )
            let avail: Int = kBlockSize - block_offset_ - kHeaderSize
            let fragment_length: Int = ((left < avail) ? left : avail)

            var type: RecordType
            let end: Bool = (left == fragment_length)
            if begin && end {
                type = .kFullType
            } else if begin {
                type = .kFirstType
            } else if end {
                type = .kLastType
            } else {
                type = .kMiddleType
            }

            s = EmitPhysicalRecord(type, ptr, fragment_length)

            ptr_ind += fragment_length
            left -= fragment_length
            begin = false
        } while s.ok() && left > 0
        return s
    }
}
