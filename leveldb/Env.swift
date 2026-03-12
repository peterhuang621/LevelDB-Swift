//
//  Env.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/12.
//

import Foundation

//public func Log(_ info_log:  Logger?,_ message:String){
//  info_log?.log(message)
//}

public class Env {
    public func NewAppendableFile(_ fname: String, _ result: UnsafeMutablePointer<WritableFile>) -> Status {
        return Status.NotSupported(Slice("NewAppendableFile"), Slice(fname))
    }

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
}

public class FileLock {
}

public class Logger {
}

public class RandomAccessFile {
}

public class SequentialFile {
}

public class WritableFile {
}
