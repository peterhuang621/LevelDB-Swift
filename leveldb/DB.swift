//
//  DB.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/16.
//

import Foundation

let kMajorVersion = 1
let kMinorVersion = 23

public class Snapshot {
}

public struct Range {
    public var start: Slice
    public var limit: Slice
    init(_ s: Slice, _ l: Slice) {
        start = s
        limit = l
    }
}

public protocol DB {
    static func Open(_ options: Options, _ name: String, _ dbptr: UnsafeMutablePointer<UnsafeMutablePointer<DB>>?) -> Status

    func Put(_ options: WriteOptions, _ key: Slice, _ value: Slice) -> Status

    func Delete(_ options: WriteOptions, _ key: Slice) -> Status

    func Write(_ options: WriteOptions, _ updates: WriteBatch) -> Status

    func Get(_ options: Options, _ key: Slice, _ value: BytesStorage) -> Status

    func NewIterator(_ options: ReadOptions) -> Iterator

    func GetSnapshot() -> Snapshot

    func ReleaseSnapshot(_ snapshot: Snapshot)

    func GetProperty(_ property: Slice, _ value: BytesStorage) -> Bool

    func GetApproximateSizes(_ range: inout Range, _ n: Int, _ sizes: UInt64)

    func CompactRange(_ begin: Slice, _ end: Slice)
}

func DestroyDB(_ name: String, _ options: Options) -> Status {
    return Status()
}

func RepairDB(_ dbname: String, _ options: Options) -> Status {
    return Status()
}
