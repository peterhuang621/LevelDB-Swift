//
//  Version_Edit.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public struct FileMetaData {
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
        var f: FileMetaData = FileMetaData()
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

        for i in 0 ..< compact_pointers_.count {
            PutVarint32(dst, Tag.kCompactPointer.rawValue)
            PutVarint32(dst, UInt32(compact_pointers_[i].first))
            PutLengthPrefixedSlice(dst, compact_pointers_[i].second.Encode())
        }

        for deleted_file_kvp in deleted_files_ {
            PutVarint32(dst, Tag.kDeletedFile.rawValue)
            PutVarint32(dst, UInt32(deleted_file_kvp.first))
            PutVarint64(dst, deleted_file_kvp.second)
        }

        for i in 0 ..< new_files_.count {
            let f: FileMetaData = new_files_[i].second
            PutVarint32(dst, Tag.kNewFile.rawValue)
            PutVarint32(dst, UInt32(new_files_[i].first))
            PutVarint64(dst, f.number)
            PutVarint64(dst, f.file_size)
            PutLengthPrefixedSlice(dst, f.smallest.Encode())
            PutLengthPrefixedSlice(dst, f.largest.Encode())
        }
    }

    public func DecodeFrom(_ src: Slice) -> Status {
        return Status()
    }

    public func DebugString() -> String {
        return ""
    }
}
