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

    public init(_ d: UnsafePointer<UInt8>, _ n: Int) {
        data_ = Data(bytes: d, count: n)
    }

    public init(_ d: [UInt8], _ n: Int) {
        data_ = Data(bytes: d, count: n)
    }

    public init(_ d: [UInt8]) {
        data_ = Data(bytes: d, count: d.count)
    }

    public init(_ d: Data, _ n: Int) {
        if d.count == n {
            data_ = d
        } else {
            data_ = d.prefix(n)
        }
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

    public mutating func clear(keepcapacity: Bool = false) {
        data_.removeAll(keepingCapacity: keepcapacity)
    }

    public mutating func remove_prefix(_ n: Int) {
        precondition(n <= size(), "Index \(n) out of bounds \(size())")
        data_.removeFirst(n)
    }

    public func ToString() -> String {
        return String(data: data_, encoding: .utf8) ?? ""
    }

    public func ToInt8Array() -> [UInt8] {
        return [UInt8](data_)
    }

    public func starts_with(_ x: Slice) -> Bool {
        return (size() >= x.size()) && (data_.prefix(x.size()) == x.data_)
    }

    public func starts_with(_ str: String) -> Bool {
        let utf8Data = Data(str.utf8)
        return (size() >= utf8Data.count) && (data_.prefix(utf8Data.count) == utf8Data)
    }

    // MARK: - Equatable & Comparable

    public func compare(_ b: Slice) -> Int {
        if data_ == b.data_ { return 0 }
        return data_.lexicographicallyPrecedes(b.data_) ? -1 : 1
    }

    public func compare(_ b: String) -> Int {
        let bdata = Data(b.utf8)
        if data_ == bdata { return 0 }
        return data_.lexicographicallyPrecedes(bdata) ? -1 : 1
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.data_ == rhs.data_
    }

    public static func == (lhs: Self, rhs: String) -> Bool {
        return lhs.data_ == Data(rhs.utf8)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.data_.lexicographicallyPrecedes(rhs.data_)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        var combined = lhs
        combined.data_.append(rhs.data_)
        return combined
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs.data_.append(rhs.data_)
    }

    public static func + (lhs: Self, rhs: String) -> Self {
        var combined = lhs
        combined.data_.append(contentsOf: rhs.utf8)
        return combined
    }

    public static func += (lhs: inout Self, rhs: String) {
        lhs.data_.append(contentsOf: rhs.utf8)
    }
}
