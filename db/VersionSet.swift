//
//  VersionSet.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/28.
//

import Foundation

public func FindFile(_ icmp: InternalKeyComparator, _ files: Array<FileMetaData>, _ key: Slice) -> Int {
    var left: Int = 0
    var right: Int = files.count
    while left < right {
        let mid: Int = (left + right) / 2
        let f: FileMetaData = files[mid]
        if icmp.Compare(f.largest.Encode(), key) < 0 { left = mid + 1 } else { right = mid }
    }
    return right
}

fileprivate func AfterFile(_ ucmp: Comparator, _ user_key: Slice?, _ f: FileMetaData) -> Bool {
    return user_key != nil && (ucmp.Compare(user_key!, f.largest.user_key()) > 0)
}

fileprivate func BeforeFile(_ ucmp: Comparator, _ user_key: Slice?, _ f: FileMetaData) -> Bool {
    return user_key != nil && (ucmp.Compare(user_key!, f.smallest.user_key()) < 0)
}

public func SomeFileOverlapsRange(_ icmp: InternalKeyComparator, _ disjoint_sorted_files: Bool, _ files: Array<FileMetaData>, _ smallest_user_key: Slice?, _ largest_user_key: Slice?) -> Bool {
    let ucmp: Comparator = icmp.user_comparator()!
    if !disjoint_sorted_files {
        for f in files {
            if AfterFile(ucmp, smallest_user_key, f) || BeforeFile(ucmp, largest_user_key, f) {} else { return true }
        }
        return false
    }

    var index: Int = 0
    if let skey = smallest_user_key {
        let small_key: InternalKey = InternalKey(
            skey,
            SequenceNumber(kMaxSequenceNumber),
            kValueTypeForSeek
        )
        index = FindFile(icmp, files, small_key.Encode())
    }

    if index >= files.count { return false }
    return !BeforeFile(ucmp, largest_user_key, files[index])
}

fileprivate func FindFile(_ icmp: InternalKeyComparator, _ files: Array<FileMetaData?>, _ key: Slice) -> Int {
    var left: Int = 0
    var right: Int = files.count
    while left < right {
        let mid: Int = (left + right) / 2
        let f: FileMetaData = files[mid]!
        if icmp.Compare(f.largest.Encode(), key) < 0 {
            left = mid + 1
        } else {
            right = mid
        }
    }
    return right
}

fileprivate func GetFileIterator(_ options: ReadOptions, _ cache_: TableCache, _ file_value: Slice) -> Iterator {
    let cache: TableCache = cache_
    if file_value.size() != 16 {
        return NewErrorIterator(Status.Corruption("FileReader invoked with unexpected value"))
    } else {
        return cache.NewIterator(options, DecodeFixed64(file_value.data()!), DecodeFixed64(file_value.data()! + 8))
    }
}

public class Version {
    private class LevelFileNumIterator: Iterator {
        private var icmp_: InternalKeyComparator
        private let flist_: Array<FileMetaData?>
        private var index_: Int
        private var value_buf_: BytesStorage = BytesStorage(16)

        init(_ icmp: InternalKeyComparator, _ flist: Array<FileMetaData?>) {
            icmp_ = icmp
            flist_ = flist
            index_ = flist.count
        }

        override public func Valid() -> Bool { return index_ < flist_.count }

        override public func Seek(_ target: Slice) { index_ = FindFile(icmp_, flist_, target) }

        override public func SeekToFirst() { index_ = 0 }

        override public func SeekToLast() { index_ = flist_.isEmpty ? 0 : flist_.count - 1 }

        override public func Next() {
            precondition(Valid())
            index_ += 1
        }

        override public func Prev() {
            precondition(Valid())
            if index_ == 0 {
                index_ = flist_.count
            } else {
                index_ -= 1
            }
        }

        override public func key() -> Slice {
            precondition(Valid())
            return flist_[index_]!.largest.Encode()
        }

        override public func value() -> Slice {
            precondition(Valid())
            EncodeFixed64(value_buf_, flist_[index_]!.number)
            EncodeFixed64(value_buf_, flist_[index_]!.file_size, 8)
            return Slice(value_buf_)
        }

        override public func status() -> Status { return Status.OK() }
    }

    public var vset_: VersionSet
    private var next_: Version!
    private var prev_: Version!
    private var refs_: Int
    private var files_: [7 of Array<FileMetaData?>] = InlineArray(repeating: Array<FileMetaData?>())
    private var file_to_compact_: FileMetaData?
    private var file_to_compact_level_: Int
    private var compaction_score_: Double
    private var compaction_level_: Int

    fileprivate init(_ vset: VersionSet) {
        vset_ = vset
        refs_ = 0
        file_to_compact_ = nil
        file_to_compact_level_ = -1
        compaction_score_ = -1
        compaction_level_ = -1
        next_ = self
        next_ = self
    }

    private func NewConcatenatingIterator(_ options: ReadOptions, _ level: Int) -> Iterator {
        let cache: TableCache = vset_.table_cache_
        return NewTwoLevelIterator(
            LevelFileNumIterator(vset_.icmp_, files_[level]),
            { opts, fileValue in
                GetFileIterator(opts, cache, fileValue) },
            options)
    }

    public func remove() {
        let p: Version = prev_
        let n: Version = next_
        p.next_ = n
        n.prev_ = p

        next_ = nil
        prev_ = nil
    }

    public struct GetStats {
        var seek_file: FileMetaData?
        var seek_file_level: Int = 0
    }
}

public class VersionSet {
    public let options_: Options
    public let table_cache_: TableCache
    public let icmp_: InternalKeyComparator

    init(_ options: Options, _ table_cache: TableCache, _ cmp: InternalKeyComparator) {
        table_cache_ = table_cache
        icmp_ = cmp
        options_ = options
    }
}

fileprivate func TargetFileSize(_ options: Options) -> Int {
    return options.max_file_size
}

fileprivate func MaxGrandParentOverlapBytes(_ options: Options) -> Int64 {
    return Int64(TargetFileSize(options) * 10)
}

fileprivate func MaxFileSizeForLevel(_ options: Options, _ level: Int) -> UInt64 {
    return UInt64(TargetFileSize(options))
}

fileprivate func TotalFileSize(_ files: Array<FileMetaData>) -> Int64 {
    var sum: Int64 = 0
    for item in files {
        sum += Int64(item.file_size)
    }
    return sum
}

fileprivate class Compaction {
    private var level_: Int
    private var max_output_file_size_: UInt64
    private var input_version_: Version?
    private var edit_: VersionEdit = VersionEdit()
    private let inputs_: [2 of Array<FileMetaData>] = [[], []]
    private var grandparents_: Array<FileMetaData> = []
    private var grandparent_index_: Int = 0
    private var seen_key_: Bool = false
    private var overlapped_bytes_: Int64 = 0
    private var level_ptrs_: [7 of Int] = [0, 0, 0, 0, 0, 0, 0]

    init(_ options: Options, _ level: Int) {
        level_ = level
        max_output_file_size_ = MaxFileSizeForLevel(options, level)
    }

    public func level() -> Int { return level_ }

    public func edit() -> VersionEdit { return edit_ }

    public func num_input_files(_ which: Int) -> Int { return inputs_[which].count }

    public func input(_ which: Int, _ i: Int) -> FileMetaData? { return inputs_[which][i] }

    public func MaxOutputFileSize() -> UInt64 { return max_output_file_size_ }

    public func IsTrivialMove() -> Bool {
        let vset: VersionSet = input_version_!.vset_
        return num_input_files(0) == 1 && num_input_files(1) == 0 && (TotalFileSize(grandparents_) <= MaxGrandParentOverlapBytes(vset.options_))
    }
//
//    // Add all inputs to this compaction as delete operations to *edit.
//    void AddInputDeletions(VersionEdit* edit)
//
//    // Returns true if the information we have available guarantees that
//    // the compaction is producing data in "level+1" for which no data exists
//    // in levels greater than "level+1".
//    bool IsBaseLevelForKey(const Slice& user_key)
//
//    // Returns true iff we should stop building the current output
//    // before processing "internal_key".
//    bool ShouldStopBefore(const Slice& internal_key)
//
//    // Release the input version for the compaction, once the compaction
//    // is successful.
//    void ReleaseInputs()
}
