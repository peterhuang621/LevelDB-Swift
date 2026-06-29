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

    private var vset_: VersionSet
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
        return NewTwoLevelIterator(
            LevelFileNumIterator(vset_.icmp_, files_[level]),
            GetFileIterator,
            vset_.table_cache_,
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

fileprivate class VersionSet {
    public let table_cache_: TableCache
    public let icmp_: InternalKeyComparator

    init(_ table_cache: TableCache, _ cmp: InternalKeyComparator) {
        table_cache_ = table_cache
        icmp_ = cmp
    }
}

fileprivate class Compaction {
}
