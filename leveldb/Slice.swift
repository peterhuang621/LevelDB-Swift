//
//  Slice.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/16.
//

import Foundation

public struct Slice: Equatable, Comparable {
    private var data_: Data

    // MARK: - Initializers

    public init() {
        data_ = Data()
    }

    public init(_ s: String) {
        data_ = Data(s.utf8)
    }

    public init(_ d: UnsafePointer<UInt8>, _ n: size_t) {
        data_ = Data(bytes: d, count: n)
    }

    public init(_ d: [UInt8], _ n: size_t) {
        data_ = Data(bytes: d, count: n)
    }

    // MARK: - Properties

    public func data() -> Data {
        return data_
    }

    public func size() -> Int {
        return data_.count
    }

    public func empty() -> Bool {
        return data_.isEmpty
    }

    public func begin() -> UnsafePointer<UInt8>? {
        return data_.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }
    }

    public func end() -> UnsafePointer<UInt8>? {
        guard let start = begin() else { return nil }
        return start.advanced(by: data_.count)
    }

    // MARK: - Slice operations

    public subscript(index: Int) -> UInt8 {
        precondition(index < size(), "Index \(index) out of bounds \(size())")
        return data_[index]
    }

    public mutating func clear() {
        data_ = Data()
    }

    public mutating func removePrefix(_ n: Int) {
        precondition(n <= size(), "Index \(n) out of bounds \(size())")
        data_.removeFirst(n)
    }

    public func toString() -> String {
        return String(data: data_, encoding: .utf8) ?? ""
    }

    public func starts_with(_ x: Slice) -> Bool {
        return (size() >= x.size()) && (data_.prefix(x.size()) == x.data_)
    }

    public func compare(_ b: Slice) -> Int {
        let minLen = min(size(), b.size())
        let cmp = data_.prefix(minLen).elementsEqual(b.data_.prefix(minLen)) ? 0 : data_.prefix(minLen).lexicographicallyPrecedes(b.data_.prefix(minLen)) ? -1 : 1
        if cmp == 0 && size() != b.size() { return -1 }
        return 0
    }

    // MARK: - Equatable & Comparable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.data_ == rhs.data_
    }

    public static func < (lhs: Slice, rhs: Slice) -> Bool {
        return lhs.compare(rhs) < 0
    }
}
