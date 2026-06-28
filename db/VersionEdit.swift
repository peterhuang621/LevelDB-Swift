//
//  Version_Edit.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class FileMetaData {
    var refs: Int = 0
    var allowed_seeks: Int = (1 << 30)
    var number: UInt64 = 0
    var file_size: UInt64 = 0
    var smallest: InternalKey = InternalKey()
    var largest: InternalKey = InternalKey()
}

private enum Tag: UInt32 {
    case kComparator = 1
    case kLogNumber = 2
    case kNextFileNumber = 3
    case kLastSequence = 4
    case kCompactPointer = 5
    case kDeletedFile = 6
    case kNewFile = 7
    // 8 was used for large value refs
    case kPrevLogNumber = 9
}

public class VersionEdit {
    private typealias DeletedFileSet = Set<DeletedFile>
    private var comparator_: BytesStorage = BytesStorage(0)
    private var log_number_: UInt64 = 0
    private var prev_log_number_: UInt64 = 0
    private var next_file_number_: UInt64 = 0
    private var last_sequence_: SequenceNumber = 0
    private var has_comparator_: Bool = false
    private var has_log_number_: Bool = false
    private var has_prev_log_number_: Bool = false
    private var has_next_file_number_: Bool = false
    private var has_last_sequence_: Bool = false
    private var compact_pointers_: ContiguousArray<(first: Int, second: InternalKey)> = []
    private var deleted_files_: DeletedFileSet = DeletedFileSet()
    private var new_files_: ContiguousArray<(first: Int, second: FileMetaData)> = []

    public struct DeletedFile: Hashable, Comparable {
        public let first: Int
        public let second: UInt64

        public static func < (lhs: DeletedFile, rhs: DeletedFile) -> Bool {
            if lhs.first != rhs.first { return lhs.first < rhs.first }
            return lhs.second < rhs.second
        }
    }

    public func Clear() {
        comparator_.clear()
        log_number_ = 0
        prev_log_number_ = 0
        last_sequence_ = 0
        next_file_number_ = 0
        has_comparator_ = false
        has_log_number_ = false
        has_prev_log_number_ = false
        has_next_file_number_ = false
        has_last_sequence_ = false
        compact_pointers_.removeAll(keepingCapacity: false)
        deleted_files_.removeAll(keepingCapacity: false)
        new_files_.removeAll(keepingCapacity: false)
    }

    public func SetComparatorName(_ name: Slice) {
        has_comparator_ = true
        comparator_ = BytesStorage(name.ToString())
    }

    public func SetLogNumber(_ num: UInt64) {
        has_log_number_ = true
        log_number_ = num
    }

    public func SetPrevLogNumber(_ num: UInt64) {
        has_prev_log_number_ = true
        prev_log_number_ = num
    }

    public func SetNextFile(_ num: UInt64) {
        has_next_file_number_ = true
        next_file_number_ = num
    }

    public func SetLastSequence(_ seq: SequenceNumber) {
        has_last_sequence_ = true
        last_sequence_ = seq
    }

    public func SetCompactPointer(_ level: Int, _ key: InternalKey) {
        compact_pointers_.append((level, key))
    }

    public func AddFile(_ level: Int, _ file: UInt64, _ file_size: UInt64, _ smallest: InternalKey, _ largest: InternalKey) {
        let f: FileMetaData = FileMetaData()
        f.number = file
        f.file_size = file_size
        f.smallest = smallest
        f.largest = largest
        new_files_.append((level, f))
    }

    public func RemoveFile(_ level: Int, _ file: UInt64) {
        deleted_files_.insert(DeletedFile(first: level, second: file))
    }

    public func EncodeTo(_ dst: inout BytesStorage) {
        if has_comparator_ {
            PutVarint32(dst, Tag.kComparator.rawValue)
            PutLengthPrefixedSlice(dst, Slice(comparator_))
        }

        if has_log_number_ {
            PutVarint32(dst, Tag.kLogNumber.rawValue)
            PutVarint64(dst, log_number_)
        }

        if has_prev_log_number_ {
            PutVarint32(dst, Tag.kPrevLogNumber.rawValue)
            PutVarint64(dst, prev_log_number_)
        }

        if has_next_file_number_ {
            PutVarint32(dst, Tag.kNextFileNumber.rawValue)
            PutVarint64(dst, next_file_number_)
        }

        if has_last_sequence_ {
            PutVarint32(dst, Tag.kLastSequence.rawValue)
            PutVarint64(dst, last_sequence_)
        }

        for (first, second) in compact_pointers_ {
            PutVarint32(dst, Tag.kCompactPointer.rawValue)
            PutVarint32(dst, UInt32(first))
            PutLengthPrefixedSlice(dst, second.Encode())
        }

        for deleted_file_kvp in deleted_files_ {
            PutVarint32(dst, Tag.kDeletedFile.rawValue)
            PutVarint32(dst, UInt32(deleted_file_kvp.first))
            PutVarint64(dst, deleted_file_kvp.second)
        }

        for (level, f) in new_files_ {
            PutVarint32(dst, Tag.kNewFile.rawValue)
            PutVarint32(dst, UInt32(level))
            PutVarint64(dst, f.number)
            PutVarint64(dst, f.file_size)
            PutLengthPrefixedSlice(dst, f.smallest.Encode())
            PutLengthPrefixedSlice(dst, f.largest.Encode())
        }
    }

    public func DecodeFrom(_ src: Slice) -> Status {
        Clear()
        var input: Slice = src
        var msg: String?
        var tag: UInt32 = 0

        var level: Int = 0
        var number: UInt64 = 0
        let f: FileMetaData = FileMetaData()
        var str: Slice = Slice()
        let key: InternalKey = InternalKey()

        while msg == nil && GetVarint32(&input, &tag) {
            switch Tag(rawValue: tag) {
            case .kComparator:
                if GetLengthPrefixedSlice(&input, &str) {
                    comparator_ = BytesStorage(str.ToString())
                    has_comparator_ = true
                } else {
                    msg = "comparator name"
                }

            case .kLogNumber:
                if GetVarint64(&input, &log_number_) {
                    has_log_number_ = true
                } else {
                    msg = "log number"
                }

            case .kPrevLogNumber:
                if GetVarint64(&input, &prev_log_number_) {
                    has_prev_log_number_ = true
                } else {
                    msg = "previous log number"
                }

            case .kNextFileNumber:
                if GetVarint64(&input, &next_file_number_) {
                    has_next_file_number_ = true
                } else {
                    msg = "next file number"
                }

            case .kLastSequence:
                if GetVarint64(&input, &last_sequence_) {
                    has_last_sequence_ = true
                } else {
                    msg = "last sequence number"
                }

            case .kCompactPointer:
                if GetLevel(&input, &level) && GetInternalKey(&input, key) {
                    compact_pointers_.append((level, key))
                } else {
                    msg = "compaction pointer"
                }

            case .kDeletedFile:
                if GetLevel(&input, &level) && GetVarint64(&input, &number) {
                    deleted_files_.insert(DeletedFile(first: level, second: number))
                } else {
                    msg = "deleted file"
                }

            case .kNewFile:
                if GetLevel(&input, &level) && GetVarint64(&input, &f.number) && GetVarint64(&input, &f.file_size) && GetInternalKey(&input, f.smallest) && GetInternalKey(&input, f.largest) {
                    new_files_.append((level, f))
                } else {
                    msg = "new-file entry"
                }

            default:
                msg = "unknown tag"
            }
        }

        if msg == nil && !input.empty() {
            msg = "invalid tag"
        }

        var result: Status = Status()
        if let msg = msg {
            result = Status.Corruption("VersionEdit", msg)
        }
        return result
    }

    public func DebugString() -> String {
        var r: String = ""
        r.append("VersionEdit {")
        if has_comparator_ {
            r.append("\n  Comparator: ")
            r.append(comparator_.getStringCopy())
        }
        if has_log_number_ {
            r.append("\n  LogNumber: ")
            AppendNumberTo(&r, log_number_)
        }
        if has_prev_log_number_ {
            r.append("\n  PrevLogNumber: ")
            AppendNumberTo(&r, prev_log_number_)
        }
        if has_next_file_number_ {
            r.append("\n  NextFile: ")
            AppendNumberTo(&r, next_file_number_)
        }
        if has_last_sequence_ {
            r.append("\n  LastSeq: ")
            AppendNumberTo(&r, last_sequence_)
        }
        for (first, second) in compact_pointers_ {
            r.append("\n  CompactPointer: ")
            AppendNumberTo(&r, first)
            r.append(" ")
            r.append(second.DebugString())
        }
        for deleted_files_kvp in deleted_files_ {
            r.append("\n  RemoveFile: ")
            AppendNumberTo(&r, deleted_files_kvp.first)
            r.append(" ")
            AppendNumberTo(&r, deleted_files_kvp.second)
        }
        for (level, f) in new_files_ {
            r.append("\n  AddFile: ")
            AppendNumberTo(&r, level)
            r.append(" ")
            AppendNumberTo(&r, f.number)
            r.append(" ")
            AppendNumberTo(&r, f.file_size)
            r.append(" ")
            r.append(f.smallest.DebugString())
            r.append(" .. ")
            r.append(f.largest.DebugString())
        }
        r.append("\n}\n")
        return r
    }
}

fileprivate func GetInternalKey(_ input: inout Slice, _ dst: InternalKey) -> Bool {
    var str: Slice = Slice()
    if GetLengthPrefixedSlice(&input, &str) {
        return dst.DecodeFrom(str)
    }
    return false
}

fileprivate func GetLevel(_ input: inout Slice, _ level: inout Int) -> Bool {
    var v: UInt32 = 0
    if GetVarint32(&input, &v) && v < config.kNumLevels {
        level = Int(v)
        return true
    } else {
        return false
    }
}
