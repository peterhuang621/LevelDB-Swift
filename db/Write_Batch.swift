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
        var input = Slice(rep_)
        if input.size() < kHeader {
            return Status.Corruption("malformed WriteBatch (too small)")
        }

        input.remove_prefix(kHeader)
        var key: Slice
        var value: Slice
        var found = 0
        while !input.empty() {
            found += 1
            let tag = ValueType(rawValue: input[0])
            input.remove_prefix(1)

            switch tag {
            case .kTypeValue:
                if GetLengthPrefixedSlice(&input, &key) && GetLengthPrefixedSlice(&input, &value) {
                    handler.Put(key, value)
                } else {
                    return Status.Corruption("bad WriteBatch Put")
                }
            case .kTypeDeletion:
                if GetLengthPrefixedSlice(&input, &key) {
                    handler.Delete(key)
                    return Status.Corruption("bad WriteBatch Delete")
                }
            default:
                return Status.Corruption("unknown WriteBatch tag")
            }
        }
        if found != WriteBatchInternal.Count(self) {
            return Status.Corruption("WriteBatch has wrong count")
        }
        return Status.OK()
    }
}

public class WriteBatchInternal {
    public static func Count(_ batch: WriteBatch) -> Int {
        return batch.rep_.withUnsafeBufferPointer {
            return Int(DecodeFixed32($0.baseAddress!.advanced(by: 8)))
        }
    }

    public static func SetCount(_ batch: inout WriteBatch, _ n: Int) {
        EncodeFixed32(dst: &batch.rep_, offset: 8, value: UInt32(n))
    }

    public static func Sequence(_ batch: WriteBatch) -> SequenceNumber {
        return SequenceNumber(DecodeFixed64(batch.rep_))
    }

    public static func SetSequence(_ batch: inout WriteBatch, _ seq: SequenceNumber) {
        EncodeFixed64(dst: &batch.rep_, value: seq)
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
