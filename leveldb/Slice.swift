//
//  Slice.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/16.
//

import Foundation

public class BytesStorage {
    private var data_: NSMutableData

    // MARK: - Initializers

    public init(_ capacity: Int) {
        data_ = NSMutableData(length: capacity) ?? NSMutableData()
    }

    public init(_ bytes: [UInt8]) {
        data_ = NSMutableData(bytes: bytes, length: bytes.count)
    }

    public init(_ string: String) {
        let utf8: [UInt8] = Array(string.utf8)
        data_ = NSMutableData(bytes: utf8, length: utf8.count)
    }

    public init(_ slice: Slice) {
        data_ = NSMutableData(bytes: slice.data(), length: slice.size())
    }

    // MARK: - Getter

    public var mutablepointer: UnsafeMutablePointer<UInt8> { data_.mutableBytes.assumingMemoryBound(to: UInt8.self) }

    public var pointer: UnsafePointer<UInt8> { data_.bytes.assumingMemoryBound(to: UInt8.self) }

    public var bufferpointer: UnsafeBufferPointer<UInt8> { UnsafeBufferPointer(start: pointer, count: count) }

    public var count: Int { data_.length }

    public var isEmpty: Bool { data_.length == 0 }

    public func resize(_ newSize: Int) {
        precondition(newSize >= 0)
        data_.length = newSize
    }

    public func clear() {
        data_.length = 0
    }

    // MARK: - Data operations

    public subscript(index: Int) -> UInt8 {
        get {
            precondition(index < data_.length && index >= 0, "Index \(index) out of bounds \(data_.length)")
            return pointer[index]
        }
        set {
            precondition(index < data_.length && index >= 0, "Index \(index) out of bounds \(data_.length)")
            mutablepointer[index] = newValue
        }
    }

    public subscript(_ bounds: Range<Int>) -> Slice {
        get {
            precondition(bounds.lowerBound >= 0 && bounds.upperBound <= data_.length, "Range \(bounds) out of bounds \(data_.length)")
            let startPtr = pointer + bounds.lowerBound
            let length = bounds.count
            return Slice(startPtr, length)
        }
        set {
            precondition(bounds.lowerBound >= 0 && bounds.upperBound <= data_.length, "Range \(bounds) out of bounds \(data_.length)")
            guard bounds.count > 0 else { return }
            precondition(bounds.count == newValue.size(), "Value size \(newValue.size()) must match range count \(bounds.count)")

            if let srcPtr = newValue.data() {
                let destPtr = mutablepointer + bounds.lowerBound
                memcpy(destPtr, srcPtr, bounds.count)
            }
        }
    }

    public subscript(_ bounds: ClosedRange<Int>) -> Slice {
        get {
            let range = Range(bounds)
            return self[range]
        }
        set {
            let range = Range(bounds)
            self[range] = newValue
        }
    }

    public func append(_ string: String) {
        string.utf8.withContiguousStorageIfAvailable {
            if let base = $0.baseAddress { data_.append(base, length: $0.count) }
        } ?? {
            string.withCString { data_.append($0, length: Int(strlen($0))) }
        }()
    }

    public func append(_ arr: [UInt8]) {
        data_.append(arr, length: arr.count)
    }

    public func append(_ byte: UInt8) {
        withUnsafePointer(to: byte) {
            data_.append($0, length: 1)
        }
    }

    public func append(_ pointer: UnsafePointer<UInt8>, _ length: Int) {
        precondition(length > 0)
        data_.append(pointer, length: length)
    }

    public func append(_ bytestorage: BytesStorage) {
        data_.append(bytestorage.pointer, length: bytestorage.count)
    }

    public func append(_ slice: Slice) {
        let ptr: UnsafePointer<UInt8>? = slice.data()
        precondition(ptr != nil && slice.size() > 0)
        data_.append(ptr!, length: slice.size())
    }

    public func getUInt8ArrayCopy() -> [UInt8] {
        return Array(bufferpointer)
    }

    public func getStringCopy() -> String {
        return String(bytes: bufferpointer, encoding: .utf8)!
    }
}

public struct Slice: Equatable {
    private var data_: UnsafePointer<UInt8>?
    private var size_: Int

    // MARK: - Initializers

    public init() {
        data_ = nil
        size_ = 0
    }

    public init(_ s: String) {
        let data: BytesStorage = BytesStorage(s)
        data_ = data.pointer
        size_ = data.count
    }

    public init(_ d: UnsafePointer<UInt8>?, _ n: Int) {
        data_ = d
        size_ = n
    }

    public init(_ d: BytesStorage, _ n: Int) {
        data_ = d.pointer
        size_ = n
    }

    public init(_ d: BytesStorage) {
        data_ = d.pointer
        size_ = d.count
    }

    // MARK: - Properties

    public func data() -> UnsafePointer<UInt8>? {
        return data_
    }

    public func size() -> Int {
        return size_
    }

    public func empty() -> Bool {
        return size_ == 0
    }

    // MARK: - Slice operations

    public subscript(index: Int) -> UInt8 {
        precondition(index < size(), "Index \(index) out of bounds \(size())")
        return data_![index]
    }

    public mutating func clear() {
        data_ = nil
        size_ = 0
    }

    public mutating func remove_prefix(_ n: Int) {
        precondition(n <= size(), "Index \(n) out of bounds \(size())")
        data_ = data_! + n
        size_ -= n
    }

    public func ToString() -> String {
        guard let ptr = data_, size_ > 0 else { return "" }
        return String(bytes: UnsafeBufferPointer(start: ptr, count: size_), encoding: .utf8)!
    }

    public func starts_with(_ x: Slice) -> Bool {
        return ((size_ >= x.size_) && (memcmp(data_, x.data_, x.size_) == 0))
    }

    public func starts_with(_ str: String) -> Bool {
        return str.utf8.withContiguousStorageIfAvailable {
            let strCount: Int = $0.count
            if self.size_ < strCount { return false }
            return memcmp(self.data_!, $0.baseAddress!, strCount) == 0
        } ?? {
            str.withCString { cStr in
                let strCount = Int(strlen(cStr))
                if self.size_ < strCount { return false }
                return memcmp(self.data_!, cStr, strCount) == 0
            }
        }()
    }

    // MARK: - Equatable & Comparable

    public func compare(_ b: Slice) -> Int {
        let min_len: Int = (size_ < b.size_) ? size_ : b.size_
        let r: Int = Int(memcmp(data_!, b.data_!, min_len))
        if r != 0 {
            return r
        }
        return (size_ < b.size_) ? -1 : 1
    }

    public static func == (_ x: Slice, _ y: Slice) -> Bool {
        return ((x.size() == y.size()) &&
            (memcmp(x.data(), y.data(), x.size()) == 0))
    }
}
