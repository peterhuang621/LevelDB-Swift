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

public class LRUHandle {
    // MARK: - Public functions

    var value: UnsafeMutableRawPointer?
    var deleter: ((Slice, UnsafeMutableRawPointer?) -> Void)?

    var next_hash: UnsafeMutablePointer<LRUHandle>?
    var next: UnsafeMutablePointer<LRUHandle>?
    var prev: UnsafeMutablePointer<LRUHandle>?

    var charge: size_t = 0
    var key_length: size_t = 0
    var in_cache: Bool = false
    var refs: UInt32 = 0
    var hash: UInt32 = 0
    var key_data: [UInt8] = [0]

    // MARK: - Public functions

    // Next is only equal to this if the LRU handle is the list head of an empty list. List heads never have meaningful keys.
    public func key() -> Slice {
        precondition(next != nil, "This is list head, no key provided")
        precondition(key_length <= key_data.count, "Invalid key length")
        return Slice(key_data, key_length)
    }
}

public class HandleTable {
    // MARK: - Private properties

    private var length_: UInt32 = 0
    private var elems_: UInt32 = 0
    private var list_: UnsafeMutablePointer<UnsafeMutablePointer<LRUHandle>?>?

    private func FindPointer(_ key: Slice, _ hash: UInt32) -> UnsafeMutablePointer<UnsafeMutablePointer<LRUHandle>?> {
        let index = Int(hash & (length_ - 1))
        var ptr = list_!.advanced(by: index)
        while let p = ptr.pointee {
            if p.pointee.hash != hash || key != p.pointee.key() {
                ptr = withUnsafeMutablePointer(to: &p.pointee.next_hash) { $0 }
            }
        }
        return ptr
    }

    private func Resize() {
        var new_length: UInt32 = 4
        while new_length < elems_ {
            new_length <<= 1
        }
        let new_list = UnsafeMutablePointer<UnsafeMutablePointer<LRUHandle>?>.allocate(
            capacity: Int(new_length)
        )
        var count: UInt32 = 0
        for i in 0 ..< Int(length_) {
            var h = list_![i]
            while h != nil {
                let next = h!.pointee.next_hash
                let hash = h!.pointee.hash
                let idx = Int(hash & (length_ - 1))
                h!.pointee.next_hash = new_list[idx]
                new_list[idx] = h
                h = next
                count += 1
            }
        }
        list_!.deallocate()

        precondition(
            elems_ == count,
            "elems_ (\(elems_)) is not equal to count (\(count))"
        )
        list_ = new_list
        length_ = new_length
    }

    // MARK: - Public functions and initializers

    init() {
        list_ = nil
        Resize()
    }

    deinit {
        list_?.deallocate()
    }

    public func Lookup(_ key: Slice, _ hash: UInt32) -> UnsafeMutablePointer<LRUHandle>? {
        return FindPointer(key, hash).pointee
    }

    public func Insert(_ h: UnsafeMutablePointer<LRUHandle>) -> UnsafeMutablePointer<LRUHandle>? {
        let ptr = FindPointer(h.pointee.key(), h.pointee.hash)
        let old = ptr.pointee

        h.pointee.next_hash = old?.pointee.next_hash
        ptr.pointee = h

        if old == nil {
            elems_ += 1
            if elems_ > length_ {
                Resize()
            }
        }

        return old
    }

    public func Remove(_ key: Slice, _ hash: UInt32) -> UnsafeMutablePointer<LRUHandle>? {
        let ptr = FindPointer(key, hash)
        let result = ptr.pointee
        if result != nil {
            ptr.pointee = result?.pointee.next_hash
            elems_ -= 1
        }
        return result
    }
}

// A single shard of sharded cache.
public class LRUCache {
    private var capacity_: size_t
    private var usage_: size_t
    private var lru_: UnsafeMutablePointer<LRUHandle>
    private var in_use_: UnsafeMutablePointer<LRUHandle>
    private var table_: HandleTable
    private let mutex_: Mutex

    init() {
        capacity_ = 0
        usage_ = 0
        table_ = HandleTable()
        mutex_ = Mutex()

        lru_ = UnsafeMutablePointer<LRUHandle>.allocate(capacity: 1)
        lru_.initialize(to: LRUHandle())
        in_use_ = UnsafeMutablePointer<LRUHandle>.allocate(capacity: 1)
        in_use_.initialize(to: LRUHandle())

        lru_.pointee.next = lru_
        lru_.pointee.prev = lru_

        in_use_.pointee.next = in_use_
        in_use_.pointee.prev = in_use_
    }

    deinit {
        lru_.deallocate()
        in_use_.deallocate()
    }

    private func LRU_Remove(_ e: UnsafeMutablePointer<LRUHandle>) {
        e.pointee.next!.pointee.prev = e.pointee.prev
        e.pointee.prev!.pointee.next = e.pointee.next
    }

    private func LRU_Append(_ list: UnsafeMutablePointer<LRUHandle>, _ e: UnsafeMutablePointer<LRUHandle>) {
        e.pointee.next = list
        e.pointee.prev = list.pointee.prev
        e.pointee.prev!.pointee.next = e
        e.pointee.next!.pointee.prev = e
    }

    private func Ref(_ e: UnsafeMutablePointer<LRUHandle>) {
        if e.pointee.refs == 1 && e.pointee.in_cache {
            LRU_Remove(e)
            LRU_Append(in_use_, e)
        }
        e.pointee.refs += 1
    }

    private func Unref(_ e: UnsafeMutablePointer<LRUHandle>) {
        precondition(
            e.pointee.refs > 0,
            "LRUHandle refs is less and equal than 0, as e.refs = \(e.pointee.refs)"
        )
        e.pointee.refs -= 1
        if e.pointee.refs == 0 {
            precondition(!e.pointee.in_cache, "LRUHandle is in cache!")
            e.pointee.deleter!(e.pointee.key(), e.pointee.value)
        } else if e.pointee.in_cache && e.pointee.refs == 1 {
            LRU_Remove(e)
            LRU_Append(lru_, e)
        }
    }

    private func FinishErase(_ e: UnsafeMutablePointer<LRUHandle>?) -> Bool {
        if let ee = e {
            precondition(ee.pointee.in_cache, "LRUHandle is in cache!")
            LRU_Remove(ee)
            ee.pointee.in_cache = false
            usage_ -= ee.pointee.charge
            Unref(ee)
        }
        return e != nil
    }
}
