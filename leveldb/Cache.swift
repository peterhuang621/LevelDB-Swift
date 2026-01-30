//
//  Cache.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/18.
//

import Foundation

// Cache uses a least-recently-used eviction policy.
public class Cache {
    // Opaque struct Handle.
    public struct Handle {}

    // MARK: - Public functions and initializers

    public init() {}

    deinit {
    }

    public func Insert(key: Slice, value: UnsafeMutableRawPointer?, charge: size_t,
                       deleter: @escaping (_ key: Slice, _ value: UnsafeMutableRawPointer?) -> Void) -> Handle {
        fatalError("Must override")
    }

    public func lookup(key: Slice) -> Handle? {
        fatalError("Must override")
    }

    public func release(_ handle: Handle) {
        fatalError("Must override")
    }

    public func value(of handle: Handle) -> UnsafeMutableRawPointer? {
        fatalError("Must override")
    }

    public func erase(key: Slice) {
        fatalError("Must override")
    }

    public func newId() -> UInt64 {
        fatalError("Must override")
    }

    public func prune() {
        // default empty
    }

    public func totalCharge() -> size_t {
        fatalError("Must override")
    }
}

final class LRUHandle {
    // MARK: - Public functions

    var value: UnsafeMutableRawPointer?
    var deleter: ((Slice, UnsafeMutableRawPointer?) -> Void)?

    var next_hash: LRUHandle?
    var next: LRUHandle?
    var prev: LRUHandle?

    var charge: size_t = 0
    var key_length: size_t = 0
    var in_cache: Bool = false
    var refs: UInt32 = 0
    var hash: UInt32 = 0
    var key_data: [UInt8] = [0]

    // MARK: - Public functions

    // Hard to use self-cycle sentinel in Swift-class, so use a createSentinel instead.
    static public func createSentinel() -> LRUHandle {
        let sentinel = LRUHandle()
        sentinel.next = sentinel
        sentinel.prev = sentinel
        return sentinel
    }

    // Next is only equal to this if the LRU handle is the list head of an empty list. List heads never have meaningful keys.
    public func key() -> Slice {
        precondition(next !== self, "This is list head, no key provided")
        return Slice(key_data, key_length)
    }
}

class HandleTable {
    // MARK: - Private properties

    private var length_: UInt32 = 0
    private var elems_: UInt32 = 0
    private var list_: [LRUHandle?] = []

    // As Swift lacks simple implementation of 2nd-level pointer, we use a tuple to get the previous node.
    private func FindPointer(_ key: Slice, _ hash: UInt32) -> (LRUHandle?, LRUHandle?) {
        var ptr = list_[Int(hash & (length_ - 1))]
        var prev: LRUHandle?
        while ptr != nil && (ptr!.hash != hash || key != ptr!.key()) {
            prev = ptr
            ptr = ptr!.next_hash
        }
        return (prev, ptr)
    }

    private func Resize() {
        var new_length: UInt32 = 4
        while new_length < elems_ {
            new_length *= 2
        }
        let new_list: [LRUHandle?] = list_
        var count: UInt32 = 0
        for i in 0 ..< Int(length_) {
            var h: LRUHandle? = list_[i]
            while h != nil {
                let next: LRUHandle? = h!.next_hash
                let hash: UInt32 = h!.hash
                var ptr: LRUHandle? = new_list[Int(hash & (length_ - 1))]
                h!.next_hash = ptr
                ptr = h
                h = next
                count += 1
            }
        }
        precondition(
            elems_ == count,
            "elems_ (\(elems_)) is not equal to count (\(count))"
        )
        list_ = new_list
        length_ = new_length
    }

    // MARK: - Public functions and initializers

    init() {
        Resize()
    }

    public func Lookup(_ key: Slice, _ hash: UInt32) -> LRUHandle? {
        return FindPointer(key, hash).1
    }

    public func Insert(_ h: LRUHandle) -> LRUHandle? {
        let (prev, ptr) = FindPointer(h.key(), h.hash)
        let old = ptr
        h.next_hash = old?.next_hash

        if prev == nil {
            list_[Int(h.hash & (length_ - 1))] = h
        } else {
            prev!.next_hash = h
        }

        if old == nil {
            elems_ += 1
            if elems_ > length_ {
                Resize()
            }
        }

        return old
    }

    public func Remove(_ key: Slice, _ hash: UInt32) -> LRUHandle? {
        let (prev, result) = FindPointer(key, hash)
        if result != nil {
            if prev == nil {
                list_[Int(hash & (length_ - 1))] = result!.next_hash
            } else {
                prev!.next_hash = result!.next_hash
            }
            elems_ -= 1
        }
        return result
    }
}


// A single shard of sharded cache.
class LRUCache {

}
