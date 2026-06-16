//
//  Arena.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/16.
//

import Foundation
import Synchronization

fileprivate let kBlockSize_: Int = 4096

public class Arena {
    private var alloc_ptr_: UnsafeMutablePointer<UInt8>?
    private var alloc_bytes_remaining_: Int = 0
    private var blocks_: ContiguousArray<UnsafeMutablePointer<UInt8>> = []
    private let memory_usage_: Atomic<Int> = Atomic<Int>(0)

    private func AllocateFallback(_ bytes: Int) -> UnsafeMutablePointer<UInt8> {
        if bytes > kBlockSize_ / 4 {
            return AllocateNewBlock(bytes)
        }

        alloc_ptr_ = AllocateNewBlock(kBlockSize_)
        alloc_bytes_remaining_ = kBlockSize_

        var result: UnsafeMutablePointer<UInt8> = alloc_ptr_!
        alloc_ptr_! += bytes
        alloc_bytes_remaining_ -= bytes
        return result
    }

    private func AllocateNewBlock(_ block_bytes: Int) -> UnsafeMutablePointer<UInt8> {
        var results: BytesStorage = BytesStorage(block_bytes)
        blocks_.append(results.mutablepointer)
        memory_usage_.add(block_bytes + MemoryLayout<UnsafeMutablePointer<UInt8>>.stride, ordering: .relaxed)
        return results.mutablepointer
    }

    public func Allocate(_ bytes: Int) -> UnsafeMutablePointer<UInt8> {
        precondition(bytes > 0, "bytes = \(bytes) should be greater than 0")
        if bytes <= alloc_bytes_remaining_ {
            var result: UnsafeMutablePointer<UInt8> = alloc_ptr_!
            alloc_ptr_! += bytes
            alloc_bytes_remaining_ -= bytes
            return result
        }
        return AllocateFallback(bytes)
    }

    public func AllocateAligned(_ bytes: Int) -> UnsafeMutablePointer<UInt8> {
        let align: Int = MemoryLayout<UnsafeMutableRawPointer>.stride
        precondition((align & (align - 1)) == 0, "pointer size should be a power of 2")
        var current_mod: Int = Int(bitPattern: alloc_ptr_!) & (align - 1)
        var slop: Int = (current_mod == 0 ? 0 : align - current_mod)
        var needed: Int = bytes + slop
        var result: UnsafeMutablePointer<UInt8>?
        if needed <= alloc_bytes_remaining_ {
            result = alloc_ptr_! + slop
            alloc_ptr_! += needed
            alloc_bytes_remaining_ -= needed
        } else {
            result = AllocateFallback(bytes)
        }
        precondition((Int(bitPattern: result!) & (align - 1)) == 0)
        return result!
    }

    public func MemoryUsage() -> Int { return memory_usage_.load(ordering: .relaxed) }
}
