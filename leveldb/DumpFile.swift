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

private class CorruptionReporter: Reader.Reporter {
    public var dst_: WritableFile?

    public func Corruption(_ bytes: UInt64, _ status: Status) {
        var r = "corruption:"
        AppendNumberTo(&r, bytes)
        r += " bytes; " + status.ToString() + "\n"
        _ = dst_!.Append(r)
    }

    public func Corruption(_ bytes: Int, _ status: Status) {
        var r = "corruption: "
        AppendNumberTo(&r, bytes)
        r += " bytes; "
        r += status.ToString()
        r.append("\n")
        _ = dst_!.Append(r)
    }
}

private func PrintLogContents<T: WritableFile>(_ env: Env, _ fname: String, _ f: (UInt64, Slice, T) -> Void, _ dst: T) -> Status {
    var file: SequentialFile?
    let s = env.NewSequentialFile(fname, &file)
    if !s.ok() {
        return s
    }
    let reporter = CorruptionReporter()
    reporter.dst_ = dst
    let reader = Reader(file, reporter, true, 0)
    var record = Slice()
    var scratch: [UInt8] = Array()
    while reader.ReadRecord(&record, &scratch) {
        f(reader.LastRecordOffset(), record, dst)
    }
    return Status.OK()
}

public class WriteBatchItemPrinter: WriteBatch.Handler {
    public var dst_: WritableFile

    init(_ dst_: WritableFile) {
        self.dst_ = dst_
    }

    public func Put(_ key: Slice, _ value: Slice) {
        var r = "  put '"
        AppendEscapedStringTo(&r, key)
        r += "' '"
        AppendEscapedStringTo(&r, value)
        r += "'\n"
        _ = dst_.Append(r)
    }

    public func Delete(_ key: Slice) {
        var r = "  del '"
        AppendEscapedStringTo(&r, key)
        r += "'\n"
        _ = dst_.Append(r)
    }
}

fileprivate func WriteBatchPrinter<T: WritableFile>(
    _ pos: UInt64,
    _ record: Slice,
    _ dst: T
) {
    var r = "--- offset "
    AppendNumberTo(&r, pos)
    r += "; "
    if record.size() < 12 {
        r += "log record length "
        AppendNumberTo(&r, record.size())
        r += " is too small\n"
        _ = dst.Append(r)
        return
    }
    let batch = WriteBatch()
    WriteBatchInternal.SetContents(batch, record)
    r += "sequence "
    AppendNumberTo(&r, WriteBatchInternal.Sequence(batch))
    r += "\n"
    _ = dst.Append(r)
    var batch_item_printer: WriteBatchItemPrinter = WriteBatchItemPrinter(dst)
    let s = batch.Iterate(&batch_item_printer)
    if !s.ok() {
        _ = dst.Append("  error: " + s.ToString() + "\n")
    }
}

private func DumpLog<T: WritableFile>(_ env: Env, _ fname: String, _ dst: T) -> Status {
    return PrintLogContents(env, fname, WriteBatchPrinter, dst)
}

fileprivate func VersionEditPrinter<T: WritableFile>(_ pos: UInt64, _ record: Slice, _ dst: T) {
    var r = "--- offset "
    AppendNumberTo(&r, pos)
    r += "; "
    let edit = VersionEdit()
    let s: Status = edit.DecodeFrom(record)
    if !s.ok() {
        r += s.ToString() + "\n"
    } else {
        r += edit.DebugString()
    }
    _ = dst.Append(r)
}

private func DumpDescriptor<T: WritableFile>(_ env: Env, _ fname: String, _ dst: T) -> Status {
    return PrintLogContents(env, fname, VersionEditPrinter, dst)
}

private func DumpTable(_ env: Env, _ fname: String, _ dst: WritableFile) -> Status {
    var file_size: UInt64 = 0
    var file: (any RandomAccessFile)?
    var table = Table()
    var s: Status = env.GetFileSize(fname, &file_size)
    if s.ok() {
        s = env.NewRandomAccessFile(fname, &file)
    }
    if s.ok() {
        s = Table.Open(Options(), &file, file_size, &table)
    }
    if !s.ok() {
        return s
    }

    var ro = ReadOptions()
    ro.fill_cache = false
    var iter: Iterator = table.NewIterator(ro)
    var r: String




  
    return Status.OK()
}

public func DumpFile(_ env: Env, _ fname: String, _ dst: WritableFile) -> Status {
    var ftype: FileType = .kTempFile
    if !GuessType(fname, &ftype) {
        return Status.InvalidArgument(Slice(fname + ": unknown file type"))
    }

    switch ftype {
    case .kLogFile:
        return DumpLog(env, fname, dst)
    case .kDescriptorFile:
        return DumpDescriptor(env, fname, dst)
    case .kTableFile:
        return DumpTable(env, fname, dst)
    default:
        break
    }
    return Status.InvalidArgument(Slice(fname + ": not a dump-able file type"))
}
