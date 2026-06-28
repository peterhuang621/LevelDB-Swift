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

public class Version {
    private class LevelFileNumIterator {}

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
}

fileprivate class Compaction {
}
