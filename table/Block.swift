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
        private let data_: [UInt8]
        var restarts_: UInt32
        var num_restarts_: UInt32
        var current_: UInt32
        var restart_index_: UInt32
        var key_: [UInt8] = []
        var value_: Slice = Slice()
        var status_: Status = Status()

        init(_ comparator: any Comparator, _ data: [UInt8], _ restarts: UInt32, _ num_restarts: UInt32) {
            precondition(num_restarts > 0, "num_restarts = \(num_restarts) should be greater than 0")
            comparator_ = comparator
            data_ = data
            restarts_ = restarts
            num_restarts_ = num_restarts
            current_ = restarts
            restart_index_ = num_restarts
            super.init()
        }

        private func NextEntryOffset() -> UInt32 { return 0 }

        private func GetRestartPoint(_ index: UInt32) -> UInt32 {
            precondition(
                index < num_restarts_,
                "index = \(index) should be less than num_restarts_ = \(num_restarts_)"
            )
            return data_
                .withUnsafeBytes {
                    DecodeFixed32(
                        $0.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: Int(restarts_ + index * 4))
                    )
                }
        }

        private func CorruptionError() {
            current_ = restarts_
            restart_index_ = num_restarts_
            status_ = Status.Corruption("bad entry in block")
            key_.removeAll(keepingCapacity: true)
            value_.clear(keepcapacity: true)
        }

        private func ParseNextKey() -> Bool {
            current_ = NextEntryOffset()
            return data_.withUnsafeBytes {
                let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let p: UnsafePointer<UInt8> = ptr.advanced(by: Int(current_))
                let limit: UnsafePointer<UInt8> = ptr.advanced(by: Int(restarts_))
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
                key_.resize(newSize: Int(shared), repeating: 0)
                key_.append(contentsOf: UnsafeBufferPointer(start: p, count: Int(non_shared)))
                value_ = Slice(p.advanced(by: Int(non_shared)), Int(value_length))
                while (restart_index_ + 1 < num_restarts_) && (GetRestartPoint(restart_index_ + 1) < current_) {
                    restart_index_ += 1
                }
                return true
            }
        }
    }

    private var data_: [UInt8]
    private var size_: Int
    private var restart_offset_: UInt32 = 0
    private var owned_: Bool

    private func NumRestarts() -> UInt32 {
        precondition(size_ >= 4, "size_ = \(size_) should be greater or equal to 4 (UInt32 size)")
        return data_.withUnsafeBytes {
            let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return DecodeFixed32(ptr.advanced(by: size_ - 4))
        }
    }

    init(_ contents: BlockContents) {
        data_ = contents.data.ToInt8Array()
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

    deinit {
        if owned_ {
            data_.removeAll(keepingCapacity: false)
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
