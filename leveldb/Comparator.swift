//
//  Comparator.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

public protocol Comparator: AnyObject {
    func Compare(_ a: Slice, _ b: Slice) -> Int

    func Compare(aBytes: [UInt8], bBytes: [UInt8]) -> Int

    func Name() -> String

    func FindShortestSeparator(_ start: inout [UInt8], _ limit: Slice)

    func FindShortSuccessor(_ key: inout [UInt8])
}

public final class BytewiseComparatorImpl: Comparator, Sendable {
    private static let singleton = BytewiseComparatorImpl()

    public func Compare(_ a: Slice, _ b: Slice) -> Int {
        return a.compare(b)
    }

    public func Compare(aBytes: [UInt8], bBytes: [UInt8]) -> Int {
        if aBytes == bBytes { return 0 }
        return aBytes.lexicographicallyPrecedes(bBytes) ? -1 : 1
    }

    public func Name() -> String {
        return "leveldb.BytewiseComparator"
    }

    public func FindShortestSeparator(_ start: inout [UInt8], _ limit: Slice) {
        let min_length = min(start.count, limit.size())
        var diff_index = 0

        while diff_index < min_length && start[diff_index] == limit[diff_index] {
            diff_index += 1
        }

        if diff_index >= min_length {
            // Do not shorten if one string is a prefix of the other
        } else {
            let diff_byte = start[diff_index]
            if diff_byte < 0xFF && (diff_byte &+ 1 < limit[diff_index]) {
                start[diff_index] &+= 1
                start.removeSubrange((diff_index + 1) ..< start.count)
                precondition(Compare(Slice(start), limit) < 0, "fail to generate new shortest separator")
            }
        }
    }

    public func FindShortSuccessor(_ key: inout [UInt8]) {
        for i in 0 ..< key.count {
            if key[i] != 0xFF {
                key[i] &+= 1
                return
            }
        }
    }

    public static func get() -> BytewiseComparatorImpl {
        return BytewiseComparatorImpl.singleton
    }

    private init() {
    }
}

public func BytewiseComparator() -> BytewiseComparatorImpl {
    return BytewiseComparatorImpl.get()
}
