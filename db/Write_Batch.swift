//
//  Write_Batch.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/2.
//

import Foundation

fileprivate let kHeader = 12

public class WriteBatch {
    fileprivate var rep_: [UInt8] = Array(repeating: 0, count: kHeader)

    init() {
        Clear()
    }

    public protocol Handler {
        func Put(_ key: Slice, _ value: Slice)
        func Delete(_ key: Slice)
    }

    public func Put(_ key: Slice, _ value: Slice) {
    }

    public func Delete() {
    }

    public func Clear() {
        rep_.removeAll(keepingCapacity: true)
    }

    public func ApproximateSize() -> Int {
        return rep_.count
    }

    public func Append(_ source: WriteBatch) {
    }

    public func Iterate(_ handler: inout Handler) -> Status {
        return Status()
    }
}

public class WriteBatchInternal {
    public static func Count(_ batch: WriteBatch) -> Int {
        return 0
    }

    public static func SetCount(_ batch: inout WriteBatch, _ n: Int) {
    }

    public static func Sequence(_ batch: WriteBatch) -> SequenceNumber {
        return 0
    }

    public static func SetSequence(_ batch: inout WriteBatch, _ seq: SequenceNumber) {
    }

    public static func Contents(_ batch: WriteBatch) -> Slice { return Slice(batch.rep_) }

    public static func ByteSize(_ batch: WriteBatch) -> Int { return batch.rep_.count }

    public static func SetContents(_ batch: inout WriteBatch, _ contents: Slice) {
    }

    public static func InsertInto(_ batch: inout WriteBatch, _ memtable: inout MemTable) -> Status {
        return Status()
    }

    public static func Append(_ dst: inout WriteBatch, _ src: WriteBatch) {
    }
}
