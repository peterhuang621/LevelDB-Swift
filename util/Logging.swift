//
//  Logging.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

public func AppendNumberTo<T: LosslessStringConvertible>(_ str: inout String, _ num: T) {
    str.append(String(num))
}

public func AppendEscapedStringTo(_ str: inout String, _ value: Slice) {
    // " " - 32 "~" - 126
    for i in 0 ..< value.size() {
        let c: UInt8 = value[i]
        if (32 ... 126).contains(c) {
            str.append(Character(UnicodeScalar(c)))
        } else {
            str.append(String(format: "\\x%02x", c))
        }
    }
}

public func NumberToString(_ num: UInt64) -> String {
    var r: String = ""
    AppendNumberTo(&r, num)
    return r
}

public func EscapeString(_ value: Slice) -> String {
    var r: String = ""
    AppendEscapedStringTo(&r, value)
    return r
}

public func ConsumeDecimalNumber(_ input: inout Slice, _ val: inout UInt64) -> Bool {
    let kMaxUint64 = UInt64.max
    let kLastDigitOfMaxUint64 = UInt64(kMaxUint64 % 10)

    var value: UInt64 = 0
    let start: UnsafePointer<UInt8> = input.data()!
    let end: UnsafePointer<UInt8> = start + input.size()
    var current: UnsafePointer<UInt8> = start
    var byte: UInt8

    while current != end {
        // "0" - 48 "9" - 57
        byte = current.pointee
        if byte < 48 || byte > 57 { break }
        let digit = UInt64(byte - 48)
        if value > kMaxUint64 / 10 || (value == kMaxUint64 / 10 && digit > kLastDigitOfMaxUint64) {
            return false
        }
        value = value * 10 + digit
        current += 1
    }

    val = value
    let digits_consumed: Int = current - start
    input.remove_prefix(digits_consumed)
    return digits_consumed != 0
}
