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

        private func CorruptionError() {
            current_ = restarts_
            restart_index_ = num_restarts_
            status_ = Status.Corruption("bad entry in block")
            key_.removeAll(keepingCapacity: true)
            value_.clear(keepcapacity: true)
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
