//
//  Env.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/12.
//

import Foundation

// public func Log(_ info_log:  Logger?,_ message:String){
//  info_log?.log(message)
// }

public class Env {
    public func RemoveDir(_ dirname: String) -> Status {
        return DeleteDir(dirname)
    }

    // DEPRECATED
    public func DeleteDir(_ dirname: String) -> Status {
        return RemoveDir(dirname)
    }

    public func RemoveFile(_ fname: String) -> Status {
        return DeleteFile(fname)
    }

    // DEPRECATED
    public func DeleteFile(_ fname: String) -> Status {
        return RemoveFile(fname)
    }

    public func NewSequentialFile(_ fname: String, _ result: inout SequentialFile?) -> Status {
        fatalError("must be override")
    }

    public func NewRandomAccessFile(_ fname: String, _ result: inout RandomAccessFile?) -> Status {
        fatalError("must be override")
    }

    public func NewWritableFile(_ fname: String, _ result: inout WritableFile?) -> Status {
        fatalError("must be override")
    }

    public func NewAppendableFile(_ fname: String, _ result: inout WritableFile?) -> Status {
        return Status.NotSupported(Slice("NewAppendableFile"), Slice(fname))
    }

    public func FileExists(_ fname: String) -> Bool {
        fatalError("must be override")
    }

    public func GetChildren(_ dir: String, _ result: [String]) -> Status {
        fatalError("must be override")
    }

    public func CreateDir(_ dirname: String) -> Status {
        fatalError("must be override")
    }

    public func RenameFile(_ src: String, _ target: String) -> Status {
        fatalError("must be override")
    }

    public func LockFile(_ fname: String, _ lock: inout FileLock?) -> Status {
        fatalError("must be override")
    }

    public func UnlockFile(_ lock: inout FileLock?) -> Status {
        fatalError("must be override")
    }

    public func Schedule(_ function: (_ arg: UnsafeMutableRawPointer) -> Void, _ arg: UnsafeMutableRawPointer) -> Status {
        fatalError("must be override")
    }

    public func StartThread(_ function: (_ arg: UnsafeMutableRawPointer) -> Void, _ arg: UnsafeMutableRawPointer) -> Status {
        fatalError("must be override")
    }

    public func GetTestDirectory(_ path: inout String) -> Status {
        fatalError("must be override")
    }

    public func NewLogger(_ fname: String, _ result: inout Logger?) -> Status {
        fatalError("must be override")
    }

    public func NowMicros() -> UInt64 {
        fatalError("must be override")
    }

    public func SleepForMicroseconds(_ micros: Int) {
        fatalError("must be override")
    }
}

public func DoWriteStringToFile(_ env: Env, _ data: Slice, _ fname: String, _ should_sync: Bool) -> Status {
    var f: WritableFile?
    var file = f!
    var s = env.NewAppendableFile(fname, &f)
    if !s.ok() {
        return s
    }

    s = file.Append(data)
    if s.ok() && should_sync {
        s = file.Sync()
    }
    if s.ok() {
        s = file.Close()
    }
    if !s.ok() {
        _ = env.RemoveFile(fname)
    }
    return s
}

public func WriteStringToFile(_ env: Env, _ data: Slice, _ fname: String) -> Status {
    return DoWriteStringToFile(env, data, fname, false)
}

public func WriteStringToFileSync(_ env: Env, _ data: Slice, _ fname: String) -> Status {
    return DoWriteStringToFile(env, data, fname, true)
}

public func ReadFileToString(_ env: Env, _ fname: String, _ data: inout String) -> Status {
    data.removeAll()
    var f: SequentialFile?
    var file = f!
    var s = env.NewSequentialFile(fname, &f)
    if !s.ok() {
        return s
    }

    let kBufferSize = 8192
    var space = Array(repeating: UInt8(0), count: kBufferSize)
    while true {
        var fragment = Slice()
        s = file.Read(kBufferSize, &fragment, space)
        if !s.ok() {
            break
        }
        data.append(fragment.toString())
        if fragment.empty() {
            break
        }
    }
    return s
}

public protocol FileLock {
}

public protocol Logger {
    func Logv(_ str: inout String)
}

public protocol RandomAccessFile {
    func Read(
        _ offset: UInt64,
        _ n: size_t,
        _ result: inout Slice,
        _ scratch: [UInt8]
    ) -> Status
}

public protocol SequentialFile {
    func Read(_ n: size_t, _ result: inout Slice, _ scratch: [UInt8]) -> Status

    func Skip(_ n: UInt64) -> Status
}

public protocol WritableFile {
    func Append(_ data: Slice) -> Status
    func Close() -> Status
    func Flush() -> Status
    func Sync() -> Status
}

public class EnvWrapper: Env {
    private var target_: Env

    public init(target_: Env) {
        self.target_ = target_
    }

    public func target() -> Env {
        return target_
    }
}
