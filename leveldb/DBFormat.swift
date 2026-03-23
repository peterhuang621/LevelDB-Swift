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

    init() {
        user_key = Slice()
        sequence = SequenceNumber()
        type = ValueType.kTypeValue
    }

    init(u: Slice, seq: SequenceNumber, t: ValueType) {
        user_key = u
        sequence = seq
        type = t
    }

    public func DebugString() -> String {
        let escapedKey = EscapeString(user_key)
        return "'\(escapedKey)' @ \(sequence) : \(type.rawValue)"
    }
}

public func InternalKeyEncodingLength(_ key: ParsedInternalKey) -> size_t {
    return key.user_key.size() + 8
}

public func AppendInternalKey(_ result: inout String, _ key: ParsedInternalKey) {
    result.append(key.user_key.ToString())
    PutFixed64(&result, PackSequenceAndType(key.sequence, key.type))
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

    public func Compare(_ akey: Slice, _ bkey: Slice) -> Int {
        var r = user_comparator_!.Compare(ExtractUserKey(akey), ExtractUserKey(bkey))
        if r == 0 {
            var a = akey
            var b = bkey
            let anum = a.data().suffix(8).withUnsafeBytes {
                DecodeFixed64($0.bindMemory(to: UInt8.self).baseAddress!)
            }
            let bnum = b.data().suffix(8).withUnsafeBytes {
                DecodeFixed64($0.bindMemory(to: UInt8.self).baseAddress!)
            }
            r = (anum > bnum) ? -1 : 1
        }
        return r
    }

    public func Compare(aStr: String, bStr: String) -> Int {
        var r = user_comparator_!.Compare(aStr: String(aStr.prefix(aStr.count - 8)), bStr: String(bStr.prefix(bStr.count - 8)))
        if r == 0 {
            var a = aStr
            var b = bStr
            let anum = a.suffix(8).withUnsafeBytes {
                DecodeFixed64($0.bindMemory(to: UInt8.self).baseAddress!)
            }
            let bnum = b.suffix(8).withUnsafeBytes {
                DecodeFixed64($0.bindMemory(to: UInt8.self).baseAddress!)
            }
            r = (anum > bnum) ? -1 : 1
        }
        return r
    }

    public func Compare(_ a: InternalKey, _ b: InternalKey) -> Int {
        return Compare(a.Encode(), b.Encode())
    }

    public func Name() -> String {
        return "leveldb.InternalKeyComparator"
    }

    public func FindShortestSeparator(_ start: inout String, _ limit: Slice) {
        guard let user_comparator_ = user_comparator_ else { fatalError("user_comparator should not be empty") }

        let user_start = ExtractUserKey(str: start)
        let user_limit = ExtractUserKey(limit)
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

        let user_key = ExtractUserKey(str: key)
        var tmp = user_key

        user_comparator_.FindShortSuccessor(&tmp)

        if tmp.count < user_key.count && user_comparator_.Compare(aStr: user_key, bStr: tmp) < 0 {
            PutFixed64(&tmp, PackSequenceAndType(UInt64(kMaxSequenceNumber), kValueTypeForSeek))
            precondition(Compare(aStr: key, bStr: tmp) < 0)
            key = tmp
        }
    }

    public func user_comparator() -> Comparator? {
        return user_comparator_
    }
}

public class InternalFilterPolicy: FilterPolicy {
    private let user_policy_: FilterPolicy?

    init(_ p: FilterPolicy?) {
        user_policy_ = p
    }

    public func Name() -> [UInt8] {
        return user_policy_!.Name()
    }

    public func CreateFilter(_ keys: inout [Slice], _ n: Int, _ dst: inout String) {
        for i in 0 ..< n {
            keys[i] = ExtractUserKey(keys[i])
        }
        user_policy_?.CreateFilter(&keys, n, &dst)
    }

    public func KeyMayMatch(_ key: Slice, _ filter: Slice) -> Bool {
        return user_policy_!.KeyMayMatch(ExtractUserKey(key), filter)
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

    public func DebugString() -> String {
        var parsed = ParsedInternalKey()
        if ParseInternalKey(Slice(rep_), &parsed) {
            return parsed.DebugString()
        }
        return "(bad)\(EscapeString(Slice(rep_)))"
    }
}

public func ParseInternalKey(_ internal_key: Slice, _ result: inout ParsedInternalKey) -> Bool {
    let n = internal_key.size()
    if n < 8 {
        return false
    }
    let num: UInt64 = internal_key.data().suffix(8).withUnsafeBytes {
        DecodeFixed64($0.bindMemory(to: UInt8.self).baseAddress!)
    }
    let c: UInt8 = UInt8(num & 0xFF)
    result.sequence = num >> 8
    result.type = ValueType(rawValue: c)!
    result.user_key = Slice(internal_key.data(), n - 8)
    return c <= ValueType.kTypeValue.rawValue
}

public class LookupKey {
    private var space_: Data = Data()
    private var start_: Int
    private var kstart_: Int
    private var end_: Int

    init(_ user_key: Slice, _ s: SequenceNumber) {
        let usize: UInt32 = UInt32(user_key.size())
        let needed = usize + 13

        space_.removeAll(keepingCapacity: true)
        space_.reserveCapacity(Int(needed))

        start_ = 0

        EncodeVarint32(&space_, usize + 8)
        kstart_ = space_.count

        space_.append(user_key.data())
        EncodeFixed64(dstData: &space_, value: PackSequenceAndType(s, kValueTypeForSeek))
        end_ = space_.count
    }
}

fileprivate func PackSequenceAndType(_ seq: UInt64, _ t: ValueType) -> UInt64 {
    precondition(seq <= kMaxSequenceNumber)
    precondition(t.rawValue <= kValueTypeForSeek.rawValue)
    return (seq << 8) | UInt64(t.rawValue)
}
