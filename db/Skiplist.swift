//
//  Skiplist.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/16.
//

import Foundation
import Synchronization

public class Skiplist<Key, Comp: Comparator> {
    private struct Node {
        private var next_: UnsafeMutablePointer<Atomic<UnsafeMutablePointer<Node>?>>?

        public let key: Key?

        init(_ k: Key?, _ next: UnsafeMutablePointer<Atomic<UnsafeMutablePointer<Node>?>>? = nil) {
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

    private let kMaxHeight = 12
    private var compare_: Comp
    private let arena_: Arena
    private var head_: UnsafeMutablePointer<Node>?
    private let max_height_: Atomic<Int>
    private var rnd_: Random

    init(_ cmp: Comp, _ arena: Arena) {
        compare_ = cmp
        arena_ = arena
        max_height_ = Atomic<Int>.init(1)
        rnd_ = Random(0xDEADBEEF)
        head_ = NewNode(nil, kMaxHeight)
        for i in 0 ..< kMaxHeight {
            head_!.pointee.SetNext(i, nil)
        }
    }

    private func NewNode(_ key: Key?, _ height: Int) -> UnsafeMutablePointer<Node> {
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
}
