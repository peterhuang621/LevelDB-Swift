//
//  Memtable.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/2.
//

import Foundation

fileprivate func GetLengthPrefixedSlice(_ data: UnsafePointer<UInt8>) -> Slice {
    var len: UInt32 = 0
    var p: UnsafePointer<UInt8> = data
    p = GetVarint32Ptr(p, p + 5, &len)!
    return Slice(p, Int(len))
}

fileprivate func EncodeKey(_ scratch: inout BytesStorage, _ target: Slice) -> UnsafePointer<UInt8> {
    scratch.clear()
    PutVarint32(scratch, UInt32(target.size()))
    scratch.append(target)
    return scratch.pointer
}

public typealias Table_ = Skiplist<UnsafePointer<UInt8>, MemTable.KeyComparator>

public class MemTable {
    private var comparator_: KeyComparator
    // Only need to double-check if the MemTable is deinited as expected.
    private var refs_: Int = 0
    private let arena_: Arena = Arena()
    fileprivate var table_: Table_

    init(_ comparator: InternalKeyComparator) {
        comparator_ = KeyComparator(comparator)
        // Use arena_ to allocate a preallocate memory to avoid the difficulties in transferring cpp template definitions to Swift.
        let dummKey: UnsafePointer<UInt8> = UnsafePointer<UInt8>(arena_.Allocate(1))

        table_ = Table_(comparator_, arena_, dummKey)
    }

    deinit {
        precondition(refs_ == 0, "refs_ = \(refs_) should be equal to 0")
    }

    public struct KeyComparator: SkipListComparator {
        public var comparator: InternalKeyComparator
        init(_ c: InternalKeyComparator) { comparator = c }
        public func callAsFunction(_ aptr: UnsafePointer<UInt8>, _ bptr: UnsafePointer<UInt8>) -> Int {
            return comparator.Compare(GetLengthPrefixedSlice(aptr), GetLengthPrefixedSlice(bptr))
        }
    }

    public func Ref() { refs_ += 1 }

    public func UnRef() {
        refs_ -= 1
        precondition(refs_ >= 0, "refs_ = \(refs_) should be greater or equal to 0")
    }

    public func ApproximateMemoryUsage() -> Int { return arena_.MemoryUsage() }

    public func NewIterator() -> Iterator { return MemTableIterator(table_) }

    public func Add(_ s: SequenceNumber, _ type: ValueType, _ key: Slice, _ value: Slice) {
        let key_size: Int = key.size()
        let val_size: Int = value.size()
        let internal_key_size: Int = key_size + 8
        let encoded_len: Int = VarintLength(UInt64(internal_key_size)) + internal_key_size + VarintLength(UInt64(val_size)) + val_size

        let buf: UnsafeMutablePointer<UInt8> = arena_.Allocate(encoded_len)
        var p: UnsafeMutablePointer<UInt8> = EncodeVarint32(buf, UInt32(internal_key_size))
        memcpy(p, key.data(), key_size)
        p += key_size
        EncodeFixed64(p, (s << 8) | UInt64(type.rawValue))
        p += 8
        p = EncodeVarint32(p, UInt32(val_size))
        memcpy(p, value.data(), val_size)
        precondition(p + val_size == buf + encoded_len)
        table_.Insert(buf)
    }

    public func Get(_ key: LookupKey, _ value: inout BytesStorage, _ s: inout Status) -> Bool {
        let memkey: Slice = key.memtable_key()
        let iter: Table_.Iterator = Table_.Iterator(table_)
        iter.Seek(memkey.data()!)
        if iter.Valid() {
            let entry: UnsafePointer<UInt8> = iter.key()
            var key_length: UInt32 = 0
            let key_ptr: UnsafePointer<UInt8> = GetVarint32Ptr(entry, entry + 5, &key_length)!
            if comparator_.comparator
                .user_comparator()!
                .Compare(Slice(key_ptr, Int(key_length) - 8), key.user_key()) == 0 {
                let tag: UInt64 = DecodeFixed64(key_ptr + Int(key_length) - 8)
                switch ValueType(rawValue: UInt8(tag & 0xFF)) {
                case .kTypeValue:
                    let v: Slice = GetLengthPrefixedSlice(key_ptr + Int(key_length))
                    value = BytesStorage(v)
                    return true
                case .kTypeDeletion:
                    s = Status.NotFound(Slice())
                    return true
                default:
                    print("unknown ValueType (tag & 0xFF) = \(tag & 0xFF)")
                    return false
                }
            }
        }
        return false
    }
}

public class MemTableIterator: Iterator {
    private var iter_: Table_.Iterator
    private var tmp_: BytesStorage = BytesStorage(0)

    init(_ table: Table_) {
        iter_ = Table_.Iterator(table)
    }

    override public func Valid() -> Bool { return iter_.Valid() }

    override public func Seek(_ k: Slice) { iter_.Seek(EncodeKey(&tmp_, k)) }

    override public func SeekToFirst() { iter_.SeekToFirst() }

    override public func SeekToLast() { iter_.SeekToLast() }

    override public func Next() { iter_.Next() }

    override public func Prev() { iter_.Prev() }

    override public func key() -> Slice { GetLengthPrefixedSlice(iter_.key()) }

    override public func value() -> Slice {
        let key_slice: Slice = GetLengthPrefixedSlice(iter_.key())
        return GetLengthPrefixedSlice(key_slice.data()! + key_slice.size())
    }

    override public func status() -> Status { return Status.OK() }
}
