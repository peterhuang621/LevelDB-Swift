//
//  Dbformat.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/19.
//

import Foundation

private let kNumLevels = 7
private let kL0_CompactionTrigger = 4
private let kL0_SlowdownWritesTrigger = 8
private let kL0_StopWritesTrigger = 12
private let kMaxMemCompactLevel = 2
private let kReadBytesPeriod = 1048576

public enum ValueType: UInt8, Sendable {
    case kTypeDeletion = 0x0
    case kTypeValue = 0x1
}

private let kValueTypeForSeek = ValueType.kTypeValue

typealias SequenceNumber = UInt64
private let kMaxSequenceNumber = ((0x1 << 56) - 1)

public struct ParsedInternalKey {
    var user_key: Slice
    var sequence: SequenceNumber
    var type: ValueType

    init(u: Slice, seq: SequenceNumber, t: ValueType) {
        user_key = u
        sequence = seq
        type = t
    }

    public func DebugString() -> String {
    }
}

public func InternalKeyEncodingLength(_ key: ParsedInternalKey) -> size_t {
    return key.user_key.size() + 8
}

public func AppendInternalKey(_ result: inout String, _ key: ParsedInternalKey) {
}

public func ExtractUserKey(_ internal_key: Slice) -> Slice {
    precondition(internal_key.size() >= 8, "internal_key.size() = \(internal_key.size()) should >= 8")
    return Slice(internal_key.data(), internal_key.size() - 8)
}

public func ExtractUserKey(str: String) -> String {
    precondition(str.count >= 8, "str.count = \(str.count) should >= 8")
    return String(str.prefix(str.count - 8))
}

public class InternalKeyComparator: Comparator {
    private let user_comparator_: Comparator?

    public init(_ c: inout Comparator?) {
        user_comparator_ = c
    }

    public func Compare(_ a: Slice, _ b: Slice) -> Int {
    }

    public func Compare(aStr: String, bStr: String) -> Int {
    }

    public func Compare(_ a: InternalKey, _ b: InternalKey) -> Int {
        return Compare(a.Encode(), b.Encode())
    }

    public func Name() -> String {
        return "leveldb.InternalKeyComparator"
    }

    public func FindShortestSeparator(_ start: inout String, _ limit: Slice) {
        guard let user_comparator_ = user_comparator_ else { fatalError("user_comparator should not be empty") }

        var user_start = ExtractUserKey(str: start)
        var user_limit = ExtractUserKey(limit)
        var tmp = String(user_start.prefix(user_limit.size()))

        user_comparator_.FindShortestSeparator(&tmp, user_limit)

        if tmp.count < user_start.count && user_comparator_.Compare(aStr: user_start, bStr: tmp) < 0 {
            PutFixed64(&tmp, PackSequenceAndType(UInt64(kMaxSequenceNumber), kValueTypeForSeek))
            precondition(Compare(aStr: start, bStr: tmp) < 0)
            precondition(Compare(aStr: tmp, bStr: limit.ToString()) < 0)
            start = tmp
        }
    }

    public func FindShortSuccessor(_ key: inout String) {
        guard let user_comparator_ = user_comparator_ else { fatalError("user_comparator should not be empty") }

        var user_key = ExtractUserKey(str: key)
        var tmp = user_key

        user_comparator_.FindShortSuccessor(&tmp)

        if tmp.count < user_key.count && user_comparator_.Compare(aStr: user_key, bStr: tmp) < 0 {
            PutFixed64(&tmp, PackSequenceAndType(UInt64(kMaxSequenceNumber), kValueTypeForSeek))
            precondition(Compare(aStr: key, bStr: tmp) < 0)
            key = tmp
        }
    }
}

public class InternalFilterPolicy: FilterPolicy {
    private let user_policy_: FilterPolicy?

    init(user_policy_: FilterPolicy?) {
        self.user_policy_ = user_policy_
    }

    public func Name() -> [UInt8] {
        <#code#>
    }

    public func CreateFilter(_ keys: Slice, _ n: Int, _ dst: inout String) {
        <#code#>
    }

    public func KeyMayMatch(_ key: Slice, _ filter: Slice) -> Bool {
        <#code#>
    }
}

public class InternalKey {
    private var rep_: String = ""

    init(_ user_key: Slice, _ s: SequenceNumber, _ t: ValueType) {
        AppendInternalKey(&rep_, ParsedInternalKey(u: user_key, seq: s, t: t))
    }

    public func DecodeFrom(_ s: Slice) -> Bool {
        rep_ = s.ToString()
        return !rep_.isEmpty
    }

    public func Encode() -> Slice {
        precondition(!rep_.isEmpty, "rep_ should be empty")
        return Slice(rep_)
    }

    public func user_key() -> Slice {
        return Slice(ExtractUserKey(str: rep_))
    }

    public func SetFrom(_ p: ParsedInternalKey) {
        rep_.removeAll()
        AppendInternalKey(&rep_, p)
    }

    public func clear() {
        rep_.removeAll()
    }

    public func DebugString() {
    }
}

public func ParseInternalKey(_ internal_key: Slice, _ result: inout ParsedInternalKey) -> Bool {
    let n = internal_key.size()
    if n < 8 {
        return false
    }
    var num: UInt64 = internal_key.data().suffix(8).withUnsafeBytes {
        DecodeFixed64($0.bindMemory(to: UInt8.self).baseAddress!)
    }
    var c: UInt8 = UInt8(num & 0xFF)
    result.sequence = num >> 8
    result.type = ValueType(rawValue: c)!
    result.user_key = Slice(internal_key.data(), n - 8)
    return c <= ValueType.kTypeValue.rawValue
}

public class LookupKey{
  
}

fileprivate func PackSequenceAndType(_ seq: UInt64, _ t: ValueType) -> UInt64 {
    precondition(seq <= kMaxSequenceNumber)
    precondition(t.rawValue <= kValueTypeForSeek.rawValue)
    return (seq << 8) | UInt64(t.rawValue)
}
