//
//  Block.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/12.
//

import Foundation

public class Block {
    private class Iter: Iterator {
        private let comparator_: any Comparator
        private let data_: UnsafePointer<UInt8>
        var restarts_: UInt32
        var num_restarts_: UInt32
        var current_: UInt32
        var restart_index_: UInt32
        var key_: BytesStorage = BytesStorage(0)
        var value_: Slice = Slice()
        var status_: Status = Status()

        init(
            _ comparator: any Comparator,
            _ data: UnsafePointer<UInt8>,
            _ restarts: UInt32,
            _ num_restarts: UInt32
        ) {
            precondition(num_restarts > 0, "num_restarts = \(num_restarts) should be greater than 0")
            comparator_ = comparator
            data_ = data
            restarts_ = restarts
            num_restarts_ = num_restarts
            current_ = restarts
            restart_index_ = num_restarts
            super.init()
        }

        private func Compare(_ a: Slice, _ b: Slice) -> Int { return comparator_.Compare(a, b) }

        private func NextEntryOffset() -> UInt32 {
            return UInt32(value_.data()!.advanced(by: value_.size()) - data_)
        }

        private func GetRestartPoint(_ index: UInt32) -> UInt32 {
            precondition(
                index < num_restarts_,
                "index = \(index) should be less than num_restarts_ = \(num_restarts_)"
            )
            return DecodeFixed32(data_ + Int(restarts_) + Int(index) * MemoryLayout<UInt32>.stride)
        }

        private func SeekToRestartPoint(_ index: UInt32) {
            key_.clear()
            restart_index_ = index
            value_ = Slice(data_ + Int(GetRestartPoint(index)), 0)
        }

        private func CorruptionError() {
            current_ = restarts_
            restart_index_ = num_restarts_
            status_ = Status.Corruption("bad entry in block")
            key_.clear()
            value_.clear()
        }

        private func ParseNextKey() -> Bool {
            current_ = NextEntryOffset()
            let p: UnsafePointer<UInt8> = data_.advanced(by: Int(current_))
            let limit: UnsafePointer<UInt8> = data_.advanced(by: Int(restarts_))
            if p >= limit {
                current_ = restarts_
                restart_index_ = num_restarts_
                return false
            }

            var shared: UInt32 = 0
            var non_shared: UInt32 = 0
            var value_length: UInt32 = 0
            let tmpp: UnsafePointer<UInt8>? = DecodeEntry(
                p,
                limit,
                &shared,
                &non_shared,
                &value_length
            )
            if tmpp == nil || key_.count < shared {
                CorruptionError()
                return false
            }
            key_.resize(Int(shared))
            key_.append(p, Int(non_shared))
            value_ = Slice(p.advanced(by: Int(non_shared)), Int(value_length))
            while (restart_index_ + 1 < num_restarts_) && (GetRestartPoint(restart_index_ + 1) < current_) {
                restart_index_ += 1
            }
            return true
        }

        override public func Valid() -> Bool { return current_ < restarts_ }

        override public func status() -> Status { return status_ }

        override public func key() -> Slice {
            precondition(Valid(), "current_ = \(current_) should be less than restarts_ = \(restarts_)")
            return Slice(key_)
        }

        override public func value() -> Slice {
            precondition(Valid(), "current_ = \(current_) should be less than restarts_ = \(restarts_)")
            return value_
        }

        override public func Next() {
            precondition(Valid(), "current_ = \(current_) should be less than restarts_ = \(restarts_)")
            _ = ParseNextKey()
        }

        override public func Prev() {
            precondition(Valid(), "current_ = \(current_) should be less than restarts_ = \(restarts_)")

            let original: UInt32 = current_
            while GetRestartPoint(restart_index_) >= original {
                if restart_index_ == 0 {
                    current_ = restarts_
                    restart_index_ = num_restarts_
                    return
                }
                restart_index_ -= 1
            }

            SeekToRestartPoint(restart_index_)
            while ParseNextKey() && (NextEntryOffset() < original) {}
        }

        override public func SeekToFirst() {
            SeekToRestartPoint(0)
            _ = ParseNextKey()
        }

        override public func SeekToLast() {
            SeekToRestartPoint(num_restarts_ - 1)
            while ParseNextKey() && (NextEntryOffset() < restarts_) {}
        }
    }

    private var data_: UnsafePointer<UInt8>
    private var size_: Int
    private var restart_offset_: UInt32 = 0
    private var owned_: Bool

    private func NumRestarts() -> UInt32 {
        let uint32Stride: Int = MemoryLayout<UInt32>.stride
        precondition(size_ >= uint32Stride, "size_ = \(size_) should be greater or equal to 4 (UInt32 size)")
        return DecodeFixed32(data_ + size_ - uint32Stride)
    }

    init(_ contents: BlockContents) {
        data_ = contents.data.data()!
        size_ = contents.data.size()
        owned_ = contents.heap_allocated

        if size_ < 4 {
            size_ = 0
        } else {
            let max_restarts_allowed: Int = (size_ - 4) / 4
            if NumRestarts() > max_restarts_allowed {
                size_ = 0
            } else {
                restart_offset_ = UInt32(size_) - (1 + NumRestarts()) * 4
            }
        }
    }

    public func size() -> Int { return size_ }

    public func NewIterator(_ comparator: any Comparator) -> Iterator {
        if size_ < 4 {
            return NewErrorIterator(Status.Corruption("bad block contents"))
        }
        let num_restarts: UInt32 = NumRestarts()
        if num_restarts == 0 {
            return NewEmptyIterator()
        }
        return Iter(comparator, data_, restart_offset_, num_restarts)
    }
}

fileprivate func DecodeEntry(
    _ ptr: UnsafePointer<UInt8>,
    _ limit: UnsafePointer<UInt8>,
    _ shared: inout UInt32,
    _ nonshared: inout UInt32
    , _ value_length: inout UInt32) -> UnsafePointer<UInt8>? {
    if limit - ptr < 3 {
        return nil
    }
    var p: UnsafePointer<UInt8>? = ptr
    shared = UInt32(p!.pointee)
    nonshared = UInt32(p!.advanced(by: 1).pointee)
    value_length = UInt32(p!.advanced(by: 2).pointee)
    if (shared | nonshared | value_length) < 128 {
        p = p!.advanced(by: 3)
    } else {
        p = GetVarint32Ptr(p!, limit, &shared)
        if p == nil {
            return nil
        }

        p = GetVarint32Ptr(p!, limit, &nonshared)
        if p == nil {
            return nil
        }

        p = GetVarint32Ptr(p!, limit, &value_length)
        if p == nil {
            return nil
        }
    }

    if UInt32(limit - p!) < (nonshared + value_length) {
        return nil
    }
    return p
}
