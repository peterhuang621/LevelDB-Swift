//
//  dumpfile.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/12.
//

import Foundation

private func GuessType(_ fname: String, _ type: inout FileType) -> Bool {
    let basename: String
    if let pos = fname.lastIndex(of: "/") {
        basename = String(fname[fname.index(after: pos)...])
    } else {
        basename = fname
    }

    var ignored: UInt64 = 0
    return ParseFileName(basename, &ignored, &type)
}

private class CorruptionReporter {
    public var dst_: WritableFile?

    public func Corruption(_ bytes: UInt64, _ status: Status) {
        var r = "corruption:"
        AppendNumberTo(&r, bytes)
        r += " bytes; " + status.ToString() + "\n"
        _ = dst_!.Append(r)
    }
}

private func PrintLogContents(_ env: Env, _ fname: String, _ f: ((UInt64, Slice, inout WritableFile) -> Void)?, _ dst: inout WritableFile) -> Status {
//    var file: SequentialFile?
//    let s = env.NewSequentialFile(fname, &file)
//    if !s.ok() { return s }
//    var reporter = CorruptionReporter()
//    reporter.dst_ = dst
//    var Reader = reader(file, &reporter, true, 0)
//    var record: Slice
//    var scratch: String
//    while reader.ReadRecord(&record, &scratch) {
//        f(reader.LastRecordOffset(), record, dst)
//    }
    return Status.OK()
}

private func DumpLog(_ env: Env, _ fname: String, _ dst: inout WritableFile) -> Status {
    //  return PrintLogContents(env, fname, WriteBatchPrinter, &dst))
    return PrintLogContents(env, fname, nil, &dst)
}

private func DumpDescriptor(_ env: Env, _ fname: String, _ dst: inout WritableFile) -> Status {
    //  return PrintLogContents(env, fname, VersionEditPrinter, &dst))
    return PrintLogContents(env, fname, nil, &dst)
}

private func DumpTable(_ env: Env, _ fname: String, _ dst: inout WritableFile) -> Status {
    //  var file_size:UInt64=0
    //  var file:RandomAccessFile
    //  var table:Table
    return Status()
}

public func DumpFile(_ env: Env, _ fname: String, _ dst: inout WritableFile) -> Status {
    var ftype: FileType = .kTempFile
    if !GuessType(fname, &ftype) {
        return Status.InvalidArgument(Slice(fname + ": unknown file type"))
    }

    switch ftype {
    case .kLogFile:
        return DumpLog(env, fname, &dst)
    case .kDescriptorFile:
        return DumpDescriptor(env, fname, &dst)
    case .kTableFile:
        return DumpTable(env, fname, &dst)
    default:
        break
    }
    return Status.InvalidArgument(Slice(fname + ": not a dump-able file type"))
}
