//
//  Logging.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/10.
//

import Foundation

func AppendNumberTo(_ str: inout String, _ num: UInt64) {
    str.append(String(num))
}

func AppendEscapedStringTo(_ str: inout String, _ value: Slice) {
    // " " - 32 "~" - 126
    for c in value.data() {
        if (32 ... 126).contains(c) {
            str.append(Character(UnicodeScalar(c)))
        } else {
            str.append(String(format: "\\x%02x", c))
        }
    }
}

func NumberToString(_ num: UInt64) -> String {
    var r = ""
    AppendNumberTo(&r, num)
    return r
}

func EscapeString(_ value: Slice) -> String {
    var r = ""
    AppendEscapedStringTo(&r, value)
    return r
}

func ConsumeDecimalNumber(_ input: inout Slice, _ val: inout UInt64) -> Bool {
    let kMaxUint64 = UInt64.max
    let kLastDigitOfMaxUint64 = UInt64(kMaxUint64 % 10)

    var value: UInt64 = 0
    var digits_consumed = 0

    for byte in input.data() {
        // "0" - 48 "9" - 57
        if byte < 48 || byte > 57 { break }
        let digit = UInt64(byte - 48)
        if value > kMaxUint64 / 10 || (value == kMaxUint64 / 10 && digit > kLastDigitOfMaxUint64) {
            return false
        }
        value = value * 10 + digit
        digits_consumed += 1
    }

    input.removePrefix(digits_consumed)
    val = value
    return digits_consumed != 0
}
