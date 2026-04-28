//
//  Log_Reader.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/26.
//

import Foundation

public class Reader {
    public protocol Reporter {
        func Corruption(_ bytes: Int, _ status: Status)
    }

    // MARK: - Private properties and functions

    private let file_: SequentialFile?
    private let reporter_: Reporter?
    private var checksum_: Bool
    private let backing_store_: [UInt8] = Array(repeating: 0, count: kBlockSize)
    private var buffer_: Slice = Slice()
    private var eof_: Bool = false

    private var last_record_offset_: UInt64 = 0
    private var end_of_buffer_offset_: UInt64 = 0
    private var initial_offset_: UInt64
    private var resyncing_: Bool

    private enum ReaderRecordType: Int {
        case kEof = 5 // (kMaxRecordType + 1)
        case kBadRecord = 6 // (kMaxRecordType + 2)
    }

    init(
        _ file: SequentialFile?,
        _ reporter: Reporter?,
        _ checksum: Bool,
        _ initial_offset: UInt64
    ) {
        file_ = file
        reporter_ = reporter
        checksum_ = checksum
        initial_offset_ = initial_offset
        resyncing_ = (initial_offset > 0)
    }

    private func SkipToInitialBlock() -> Bool {
        let offset_in_block: UInt64 = initial_offset_ % UInt64(kBlockSize)
        var block_start_location: UInt64 = initial_offset_ - UInt64(offset_in_block)

        if offset_in_block > kBlockSize - 6 {
            block_start_location += UInt64(kBlockSize)
        }

        end_of_buffer_offset_ = block_start_location

        if block_start_location > 0 {
            let skip_status = file_!.Skip(block_start_location)
            if !skip_status.ok() {
                ReportDrop(block_start_location, skip_status)
                return false
            }
        }

        return true
    }

    private func ReadPhysicalRecord(_ result: inout Slice) -> UInt {
        while true {
            if buffer_.size() < kHeaderSize {
                if !eof_ {
                    buffer_.clear(keepcapacity: true)
                    let status = file_!.Read(kBlockSize, &buffer_, backing_store_)
                    end_of_buffer_offset_ += UInt64(buffer_.size())
                    if !status.ok() {
                        buffer_.clear(keepcapacity: true)
                        ReportDrop(UInt64(kBlockSize), status)
                        eof_ = true
                        return UInt(ReaderRecordType.kEof.rawValue)
                    } else if buffer_.size() < kBlockSize {
                        eof_ = true
                    }
                    continue
                } else {
                    buffer_.clear(keepcapacity: true)
                    return UInt(ReaderRecordType.kEof.rawValue)
                }
            }

            let header = buffer_.data()
            let a: UInt32 = UInt32(header[4]) & 0xFF
            let b: UInt32 = UInt32(header[5]) & 0xFF
            let type: UInt = UInt(header[6])
            let length: UInt32 = (a | (b << 8))

            if UInt32(kHeaderSize) + length > UInt32(buffer_.size()) {
                let drop_size = buffer_.size()
                buffer_.clear(keepcapacity: true)
                if !eof_ {
                    ReportCorruption(UInt64(drop_size), "bad record length")
                    return UInt(ReaderRecordType.kBadRecord.rawValue)
                }
                return UInt(ReaderRecordType.kEof.rawValue)
            }

            if type == RecordType.kZeroType.rawValue && length == 0 {
                buffer_.clear(keepcapacity: true)
                return UInt(ReaderRecordType.kBadRecord.rawValue)
            }

            if checksum_ {
                var expected_crc: UInt32 = 0
                var actual_crc: UInt32 = 0
                header.withUnsafeBytes {
                    let pointer = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    expected_crc = Unmask(DecodeFixed32(pointer))
                    actual_crc = Value(pointer.advanced(by: 6), Int(1 + length))
                }

                if actual_crc != expected_crc {
                    let drop_size = buffer_.size()
                    buffer_.clear(keepcapacity: true)
                    ReportCorruption(UInt64(drop_size), "checksum mismatch")
                    return UInt(ReaderRecordType.kBadRecord.rawValue)
                }
            }

            buffer_.remove_prefix(kHeaderSize + Int(length))

            let currentRecordOffset = end_of_buffer_offset_
                - UInt64(buffer_.size())
                - UInt64(kHeaderSize)
            let initialRecordEndOffset = initial_offset_ + UInt64(length)
            if currentRecordOffset < initialRecordEndOffset {
                result.clear()
                return UInt(ReaderRecordType.kBadRecord.rawValue)
            }

            result = Slice(header.suffix(header.count - kHeaderSize), Int(length))
            return type
        }
    }

    private func ReportCorruption(_ bytes: UInt64, _ reason: String) {
        ReportDrop(bytes, Status.Corruption(reason))
    }

    private func ReportDrop(_ bytes: UInt64, _ reason: Status) {
        guard let reporter = reporter_,
              end_of_buffer_offset_ - UInt64(buffer_.size()) - bytes >= initial_offset_
        else {
            return
        }

        reporter.Corruption(Int(bytes), reason)
    }

    // MARK: - Public functions

    public func ReadRecord(_ record: inout Slice, _ scratch: inout [UInt8]) -> Bool {
        if last_record_offset_ < initial_offset_ {
            if !SkipToInitialBlock() {
                return false
            }
        }

        scratch.removeAll(keepingCapacity: true)
        record.clear(keepcapacity: true)

        var in_fragmented_record = false
        var prospective_record_offset: UInt64 = 0

        var fragment = Slice()
        while true {
            let record_type: RecordType = RecordType(rawValue: Int(ReadPhysicalRecord(&fragment)))!

            // Caution to overflow or underflow.
            let physical_record_offset = end_of_buffer_offset_ - UInt64(buffer_.size()) - UInt64(kHeaderSize) - UInt64(fragment.size())

            if resyncing_ {
                switch record_type {
                case .kMiddleType:
                    continue
                case .kLastType:
                    resyncing_ = false
                    continue
                default:
                    resyncing_ = false
                }
            }

            switch record_type {
            case .kFullType:
                if in_fragmented_record {
                    if !scratch.isEmpty {
                        ReportCorruption(UInt64(scratch.count), "partial record without end(1)")
                    }
                }
                prospective_record_offset = physical_record_offset
                scratch.removeAll(keepingCapacity: true)
                record = fragment
                last_record_offset_ = prospective_record_offset
                return true

            case .kFirstType:
                if in_fragmented_record {
                    if !scratch.isEmpty {
                        ReportCorruption(UInt64(scratch.count), "partial record without end(2)")
                    }
                }
                prospective_record_offset = physical_record_offset
                scratch = fragment.ToInt8Array()
                in_fragmented_record = true

            case .kMiddleType:
                if !in_fragmented_record {
                    ReportCorruption(UInt64(scratch.count), "missing start of fragmented record(1)")
                } else {
                    scratch.append(contentsOf: fragment.data())
                }

            case .kLastType:
                if !in_fragmented_record {
                    ReportCorruption(UInt64(scratch.count), "missing start of fragmented record(2)")
                } else {
                    scratch.append(contentsOf: fragment.data())
                    record = Slice(scratch)
                    last_record_offset_ = prospective_record_offset
                    return true
                }

            case RecordType(rawValue: ReaderRecordType.kEof.rawValue):
                if in_fragmented_record {
                    scratch.removeAll(keepingCapacity: true)
                }
                return false

            case RecordType(rawValue: ReaderRecordType.kBadRecord.rawValue):
                if in_fragmented_record {
                    ReportCorruption(UInt64(scratch.count), "error in middle of record")
                    in_fragmented_record = false
                    scratch.removeAll(keepingCapacity: true)
                }

            default:
                let buf = String(format: "unknown record type %u", UInt(record_type.rawValue))
                ReportCorruption(UInt64(fragment.size()) + UInt64(in_fragmented_record ? scratch.count : 0), buf)
                in_fragmented_record = false
                scratch.removeAll(keepingCapacity: true)
            }
        }
        return false
    }

    public func LastRecordOffset() -> UInt64 {
        return last_record_offset_
    }
}
