//
//  Skiplist.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/16.
//

import Foundation
import Synchronization

public protocol SkipListComparator {
    associatedtype Key
    func callAsFunction(_ a: Key, _ b: Key) -> Int
}

public class Skiplist<Key, Comp: SkipListComparator> where Comp.Key == Key {
    // MARK: - Private properties, initializers and functions

    private struct Node {
        private var next_: UnsafeMutablePointer<Atomic<UnsafeMutablePointer<Node>?>>?

        public var key: Key

        init(_ k: Key, _ next: UnsafeMutablePointer<Atomic<UnsafeMutablePointer<Node>?>>? = nil) {
            key = k
            next_ = next
        }

        public func Next(_ n: Int) -> UnsafeMutablePointer<Node>? {
            precondition(n >= 0, "n = \(n) should be greater or equal to 0")
            return next_?[n].load(ordering: .acquiring)
        }

        public func SetNext(_ n: Int, _ x: UnsafeMutablePointer<Node>?) {
            precondition(n >= 0, "n = \(n) should be greater or equal to 0")
            next_?[n].store(x, ordering: .releasing)
        }

        public func NoBarrier_Next(_ n: Int) -> UnsafeMutablePointer<Node>? {
            precondition(n >= 0, "n = \(n) should be greater or equal to 0")
            return next_?[n].load(ordering: .relaxed)
        }

        public func NoBarrier_SetNext(_ n: Int, _ x: UnsafeMutablePointer<Node>?) {
            precondition(n >= 0, "n = \(n) should be greater or equal to 0")
            next_?[n].store(x, ordering: .relaxed)
        }
    }

    private let kMaxHeight: Int = 12
    private var compare_: Comp
    private let arena_: Arena
    private var head_: UnsafeMutablePointer<Node>!
    private let max_height_: Atomic<Int>
    private var rnd_: Random
    private let kBranching: UInt = 4

    init(_ cmp: Comp, _ arena: Arena, _ dummyKey: Key) {
        compare_ = cmp
        arena_ = arena
        max_height_ = Atomic<Int>.init(1)
        rnd_ = Random(0xDEADBEEF)
        head_ = NewNode(dummyKey, kMaxHeight)
        for i in 0 ..< kMaxHeight {
            head_.pointee.SetNext(i, nil)
        }
    }

    private func GetMaxHeight() -> Int { return max_height_.load(ordering: .relaxed) }

    private func NewNode(_ key: Key, _ height: Int) -> UnsafeMutablePointer<Node> {
        let nodeSize: Int = MemoryLayout<Node>.stride
        let atomicPtrSize: Int = MemoryLayout<Atomic<UnsafeMutablePointer<Node>?>>.stride
        let totalBytes: Int = nodeSize + (height * atomicPtrSize)
        let node_memory: UnsafeMutableRawPointer = UnsafeMutableRawPointer(arena_.AllocateAligned(totalBytes))

        let data_section: UnsafeMutableRawPointer = node_memory.advanced(by: nodeSize)
        let data_iter = data_section.bindMemory(
            to: Atomic<UnsafeMutablePointer<Node>?>.self,
            capacity: height
        )
        for i in 0 ..< height {
            data_iter.advanced(by: i).initialize(to: Atomic(nil))
        }

        let node_iter = node_memory.bindMemory(to: Node.self, capacity: 1)
        node_iter.initialize(to: Node(key, data_iter))

        return node_iter
    }

    private func RandomHeight() -> Int {
        var height: Int = 1
        while (height < kMaxHeight) && (rnd_.OneIn(Int(kBranching))) {
            height += 1
        }
        precondition(height > 0, "height = \(height) should be greater than 0")
        precondition(height <= kMaxHeight, "height = \(height) should be less or equal to kMaxHeight = \(kMaxHeight)")
        return height
    }

    private func Equal(_ a: Key, _ b: Key) -> Bool { return (compare_(a, b) == 0) }

    private func KeyIsAfterNode(_ key: Key, _ n: UnsafePointer<Node>?) -> Bool {
        guard let n = n else { return false }
        return compare_(n.pointee.key, key) < 0
    }

    private func FindGreaterOrEqual(_ key: Key, _ prev: UnsafeMutablePointer<UnsafeMutablePointer<Node>?>?) -> UnsafeMutablePointer<Node>? {
        var x: UnsafeMutablePointer<Node> = head_
        var level: Int = GetMaxHeight() - 1
        while true {
            let next: UnsafeMutablePointer<Node>? = x.pointee.Next(level)
            if KeyIsAfterNode(key, next) {
                x = next!
            } else {
                prev?[level] = x
                if level == 0 {
                    return next
                } else {
                    level -= 1
                }
            }
        }
    }

    private func FindLessThan(_ key: Key) -> UnsafeMutablePointer<Node>? {
        var x: UnsafeMutablePointer<Node> = head_
        var level: Int = GetMaxHeight() - 1
        while true {
            precondition(x == head_ || compare_(x.pointee.key, key) < 0)
            let next: UnsafeMutablePointer<Node>? = x.pointee.Next(level)
            if next != nil || compare_(next!.pointee.key, key) >= 0 {
                if level == 0 { return x } else { level -= 1 }
            } else {
                x = next!
            }
        }
    }

    private func FindLast() -> UnsafeMutablePointer<Node>? {
        var x: UnsafeMutablePointer<Node> = head_
        var level: Int = GetMaxHeight() - 1
        while true {
            let next: UnsafeMutablePointer<Node>? = x.pointee.Next(level)
            if next == nil {
                if level == 0 { return x } else { level -= 1 }
            } else {
                x = next!
            }
        }
    }

    // MARK: - Public functions

    public class Iterator {
        private let list_: Skiplist
        private var node_: UnsafePointer<Node>?

        init(_ list: Skiplist) {
            list_ = list
        }

        public func Valid() -> Bool {
            return true
        }

        public func key() -> Key? {
            return nil
        }

        public func Next() {}

        public func Prev() {}

        public func Seek(_ target: Key) {}

        public func SeekToFirst() {}

        public func SeekToLast() {}
    }

    public func Insert(_ key: Key) {
        var prev: ContiguousArray<UnsafeMutablePointer<Node>?> = ContiguousArray(
            repeating: nil,
            count: kMaxHeight
        )
        var x: UnsafeMutablePointer<Node>? = prev.withUnsafeMutableBufferPointer { FindGreaterOrEqual(key, $0.baseAddress) }

        precondition(x == nil || !Equal(key, x!.pointee.key))

        let height: Int = RandomHeight()
        if height > GetMaxHeight() {
            for i in GetMaxHeight() ..< height { prev[i] = head_ }
            max_height_.store(height, ordering: .relaxed)
        }

        x = NewNode(key, height)
        for i in 0 ..< height {
            x!.pointee.NoBarrier_SetNext(i, prev[i]!.pointee.NoBarrier_Next(i))
            prev[i]!.pointee.SetNext(i, x)
        }
    }

    public func Contains(_ key: Key) -> Bool {
        let x: UnsafeMutablePointer<Node>? = FindGreaterOrEqual(key, nil)
        if x != nil && Equal(key, x!.pointee.key) {
            return true
        } else {
            return false
        }
    }
}
