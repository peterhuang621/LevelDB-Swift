//
//  Status.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/16.
//

import Foundation

public struct Status {
    private let state_: UnsafePointer<UInt8>?

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

    private init(_ state: UnsafePointer<UInt8>?) {
        state_ = state
    }

    private init(_ code: Code, _ msg: Slice, _ msg2: Slice) {
        precondition(code != .kOk, "code = \(code) is not kOk")
        let len1: Int = msg.size()
        let len2: Int = msg2.size()
        var size: UInt32 = UInt32(len1 + (len2 > 0 ? (2 + len2) : 0))

        let data: BytesStorage = BytesStorage(Int(size) + 5)
        memcpy(data.mutablepointer, &size, MemoryLayout<UInt32>.stride)
        data[4] = code.rawValue
        memcpy(data.mutablepointer + 5, msg.data(), len1)
        if len2 > 0 {
            data[len1 + 5] = UInt8(ascii: ":")
            data[len1 + 6] = UInt8(ascii: " ")
            memcpy(data.mutablepointer + len1 + 7, msg2.data(), len2)
        }

        state_ = data.pointer
    }

    // MARK: - Query Methods

    public static func OK() -> Status { return Status() }

    public static func NotFound(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kNotFound, msg, msg2)
    }

    public static func Corruption(_ msg: Slice, _ msg2: Slice = Slice()) -> Status {
        return Status(.kCorruption, msg, msg2)
    }

    public static func Corruption(_ msg: String, _ msg2: String = String()) -> Status {
        return Status(.kCorruption, Slice(msg), Slice(msg2))
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

    private static func CopyState(_ state: Data?) -> Data? {
        return state
    }

    public func ToString() -> String {
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

        let result: BytesStorage = BytesStorage(type)
        var length: UInt32 = 0
        memcpy(&length, state_, MemoryLayout<UInt32>.stride)
        result.append(state_ + 5, Int(length))
        return result.getStringCopy()
    }
}
