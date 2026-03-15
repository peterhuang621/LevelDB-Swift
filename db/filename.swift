//
//  filename.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/15.
//

import Foundation

public enum FileType {
    case kLogFile
    case kDBLockFile
    case kTableFile
    case kDescriptorFile
    case kCurrentFile
    case kTempFile
    case kInfoLogFile // Either the current one, or an old one
}

private func MakeFileName(_ dbname: String, _ number: UInt64, suffix: String) -> String {
    let buf = String(format: "/%06llu.%@", number, suffix)
    return dbname + buf
}

private func MakeFileName(_ dbname: String, _ number: UInt64, charArray: [UInt8]) -> String {
    var tmp = String(bytes: charArray, encoding: .utf8) ?? ""
    let buf = String(format: "/%06llu.%@", number, tmp)
    return dbname + buf
}

public func LogFileName(_ dbname: String, _ number: UInt64) -> String {
    precondition(number > 0, "invalid number = \(number) and it should be greater than zero")
    return MakeFileName(dbname, number, suffix: "log")
}

public func TableFileName(_ dbname: String, _ number: UInt64) -> String {
    precondition(number > 0, "invalid number = \(number) and it should be greater than zero")
    return MakeFileName(dbname, number, suffix: "ldb")
}

public func SSTableFileName(_ dbname: String, _ number: UInt64) -> String {
    precondition(number > 0, "invalid number = \(number) and it should be greater than zero")
    return MakeFileName(dbname, number, suffix: "sst")
}

public func DescriptorFileName(_ dbname: String, _ number: UInt64) -> String {
    precondition(number > 0, "invalid number = \(number) and it should be greater than zero")
    return dbname + String(format: "/MANIFEST-%06llu", number)
}

public func CurrentFileName(_ dbname: String) -> String {
    return dbname + "/CURRENT"
}

public func LockFileName(_ dbname: String) -> String {
    return dbname + "/LOCK"
}

public func TempFileName(_ dbname: String, _ number: UInt64) -> String {
    precondition(number > 0, "invalid number = \(number) and it should be greater than zero")
    return MakeFileName(dbname, number, suffix: "dbtmp")
}

public func InfoLogFileName(_ dbname: String) -> String {
    return dbname + "/LOG"
}

public func OldInfoLogFileName(_ dbname: String) -> String {
    return dbname + "/LOG.old"
}

public func ParseFileName(_ filename: String, _ number: inout UInt64, _ type: inout FileType) -> Bool {
    var rest = Slice(filename)
    if rest == "CURRENT" {
        number = 0
        type = .kCurrentFile
    } else if rest == "LOCK" {
        number = 0
        type = .kDBLockFile
    } else if rest == "LOG" || rest == "LOG.old" {
        number = 0
        type = .kInfoLogFile
    } else if rest.starts_with("MANIFEST-") {
        rest.remove_prefix(strlen("MANIFEST-"))
        var num: UInt64 = 0
        if !ConsumeDecimalNumber(&rest, &num) {
            return false
        }
        if !rest.empty() {
            return false
        }
        type = .kDescriptorFile
        number = num
    } else {
        // Avoid strtoull() to keep filename format independent of the current locale
        var num: UInt64 = 0
        if !ConsumeDecimalNumber(&rest, &num) {
            return false
        }
        var suffix = rest
        if suffix == Slice(".log") {
            type = .kLogFile
        } else if suffix == Slice(".sst") || suffix == Slice(".ldb") {
            type = .kTableFile
        } else if suffix == Slice(".dbtmp") {
            type = .kTempFile
        } else {
            return false
        }
        number = num
    }
    return true
}

public func SetCurrentFile(_ env: Env, _ dbname: String, _ descriptor_number: UInt64) -> Status {
    let manifest = DescriptorFileName(dbname, descriptor_number)
    var contents = Slice(manifest)
    precondition(contents.starts_with(dbname + "/"))
    contents.remove_prefix(dbname.count + 1)
    let tmp = TempFileName(dbname, descriptor_number)
    var s = WriteStringToFileSync(env, contents + "\n", tmp)
    if s.ok() {
        s = env.RenameFile(tmp, CurrentFileName(dbname))
    }
    if !s.ok() {
        _ = env.RemoveFile(tmp)
    }
    return s
}
