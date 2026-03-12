//
//  Comparator.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

protocol Comparator {
    func Compare(_ a: Slice, _ b: Slice) -> Int

    func Name() -> String

    func FindShortestSeparator(_ start: inout String, _ limit: Slice)

    func FindShortSuccessor(_ key: inout String)
}

public final class BytewiseComparatorImpl: Comparator, Sendable {
    private static let singleton = BytewiseComparatorImpl()

    public func Compare(_ a: Slice, _ b: Slice) -> Int {
        return a.compare(b)
    }

    public func Name() -> String {
        return "leveldb.BytewiseComparator"
    }

    public func FindShortestSeparator(_ start: inout String, _ limit: Slice) {
        var startBytes = Array(start.utf8)

        let min_length = min(startBytes.count, limit.size())
        var diff_index = 0

        while diff_index < min_length && startBytes[diff_index] == limit[diff_index] {
            diff_index += 1
        }

        if diff_index >= min_length {
            // Do not shorten if one string is a prefix of the other
        } else {
            let diff_byte = startBytes[diff_index]
            if diff_byte < 0xFF && (diff_byte &+ 1 < limit[diff_index]) {
                startBytes[diff_index] &+= 1
                startBytes.removeSubrange((diff_index + 1) ..< startBytes.count)
                start = String(decoding: startBytes, as: UTF8.self)
                precondition(Compare(Slice(startBytes), limit) < 0, "fail to generate new shortest separator")
            }
        }
    }

    public func FindShortSuccessor(_ key: inout String) {
        var bytes = Array(key.utf8)
        for i in 0 ..< bytes.count {
            if bytes[i] != 0xFF {
                bytes[i] &+= 1
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
