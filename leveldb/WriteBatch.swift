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
        WriteBatchInternal.SetCount(self, WriteBatchInternal.Count(self) + 1)
        rep_.append(ValueType.kTypeValue.rawValue)
        PutLengthPrefixedSlice(&rep_, key)
        PutLengthPrefixedSlice(&rep_, value)
    }

    public func Delete(_ key: Slice) {
        WriteBatchInternal.SetCount(self, WriteBatchInternal.Count(self) + 1)
        rep_.append(ValueType.kTypeDeletion.rawValue)
        PutLengthPrefixedSlice(&rep_, key)
    }

    public func Clear() {
        rep_.removeAll(keepingCapacity: true)
    }

    public func ApproximateSize() -> Int {
        return rep_.count
    }

    public func Append(_ source: WriteBatch) {
        WriteBatchInternal.Append(self, source)
    }

    public func Iterate<T: Handler>(_ handler: inout T) -> Status {
        var input = Slice(rep_)
        if input.size() < kHeader {
            return Status.Corruption("malformed WriteBatch (too small)")
        }

        input.remove_prefix(kHeader)
        var key = Slice()
        var value = Slice()
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

public class MemTableInserter: WriteBatch.Handler {
    public var sequence_: SequenceNumber
    public var mem_: MemTable

    init(_ sequence_: SequenceNumber, _ mem_: MemTable) {
        self.sequence_ = sequence_
        self.mem_ = mem_
    }

    public func Put(_ key: Slice, _ value: Slice) {
        mem_.Add(sequence_, ValueType.kTypeValue, key, value)
        sequence_ += 1
    }

    public func Delete(_ key: Slice) {
        mem_.Add(sequence_, ValueType.kTypeValue, key, Slice())
        sequence_ += 1
    }
}

public class WriteBatchInternal {
    public static func Count(_ batch: WriteBatch) -> Int {
        return batch.rep_.withUnsafeBufferPointer {
            return Int(DecodeFixed32($0.baseAddress!.advanced(by: 8)))
        }
    }

    public static func SetCount(_ batch: WriteBatch, _ n: Int) {
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

    public static func SetContents(_ batch: WriteBatch, _ contents: Slice) {
        precondition(contents.size() >= kHeader, "contents.size() = \(contents.size()) should be equal or greater than kHeader = \(kHeader)")
        batch.rep_ = contents.ToInt8Array()
    }

    public static func InsertInto(_ batch: WriteBatch, _ memtable: MemTable) -> Status {
        var inserter = MemTableInserter(WriteBatchInternal.Sequence(batch), memtable)
        return batch.Iterate(&inserter)
    }

    public static func Append(_ dst: WriteBatch, _ src: WriteBatch) {
        SetCount(dst, Count(dst) + Count(src))
        precondition(
            src.rep_.count >= kHeader,
            "src.rep_.count = \(src.rep_.count) should be equal or greater than kHeader = \(kHeader)"
        )
        let srcWithoutHeaderbuf = src.rep_.suffix(from: kHeader)
        dst.rep_.append(contentsOf: srcWithoutHeaderbuf)
    }
}
