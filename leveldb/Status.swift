//
//  Status.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/16.
//

import Foundation

public struct Status {
    private let state_: Data?

    private enum Code: UInt8 {
        case kOk = 0
        case kNotFound
        case kCorruption
        case kNotSupported
        case kInvalidArgument
        case kIOError
        case k_NOT_SETTING
    }

    // MARK: - Initializers

    public init() {
        state_ = nil
    }

    public init(_ rhs: Status) {
        state_ = rhs.state_
    }

    private init(_ state_: Data?) {
        self.state_ = state_
    }

    private init(_ code: Code, _ msg: Slice, _ msg2: Slice) {
        precondition(code != .kOk, "code = \(code) is not kOk")
        let len1 = msg.size()
        let len2 = msg2.size()
        let size = len1 + (len2 > 0 ? (2 + len2) : 0)

        var data = Data(capacity: size + 5)

        var length32 = UInt32(size)
        data.append(Data(bytes: &length32, count: 4))
        data.append(UInt8(code.rawValue))
        data.append(msg.data())

        if len2 > 0 {
            data.append(UInt8(ascii: ":"))
            data.append(UInt8(ascii: " "))
            data.append(msg2.data())
        }

        state_ = data
    }

    // MARK: - Query Methods

    public static func OK() -> Status { return Status() }

    public static func NotFound(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kNotFound, msg, msg2)
    }

    public static func Corruption(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kCorruption, msg, msg2)
    }

    public static func NotSupported(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kNotSupported, msg, msg2)
    }

    public static func InvalidArgument(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kInvalidArgument, msg, msg2)
    }

    public static func IOError(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kIOError, msg, msg2)
    }

    // Returns true if the status indicates success.
    public func ok() -> Bool { return state_ == nil }

    // Returns true iff the status indicates a NotFound error.
    public func IsNotFound() -> Bool { return code() == .kNotFound }

    // Returns true iff the status indicates a Corruption error.
    public func IsCorruption() -> Bool { return code() == .kCorruption }

    // Returns true iff the status indicates an IOError.
    public func IsIOError() -> Bool { return code() == .kIOError }

    // Returns true iff the status indicates a NotSupportedError.
    public func IsNotSupportedError() -> Bool { return code() == .kNotSupported }

    // Returns true iff the status indicates an InvalidArgument.
    public func IsInvalidArgument() -> Bool { return code() == .kInvalidArgument }

    private func code() -> Code {
        return (state_ == nil) ? Code.kOk : Code(rawValue: state_![4])!
    }

    private func length() -> UInt32 {
        return state_?.withUnsafeBytes {
            $0.load(as: UInt32.self)
        } ?? 0
    }

    private static func CopyState(_ state: Data?) -> Data? {
        return state
    }

    private func ToString() -> String {
        guard let state_ else { return "OK" }
        let type: String
        switch code() {
        case .kOk:
            type = "OK"
        case .kNotFound:
            type = "NotFound: "
        case .kCorruption:
            type = "Corruption: "
        case .kNotSupported:
            type = "Not implemented: "
        case .kInvalidArgument:
            type = "Invalid argument: "
        case .kIOError:
            type = "IO error: "
        default:
            type = "Unknown code(\(code())): "
        }

        let msgData = state_.subdata(in: 5 ..< (5 + Int(length())))
        return type + String(decoding: msgData, as: UTF8.self)
    }
}
