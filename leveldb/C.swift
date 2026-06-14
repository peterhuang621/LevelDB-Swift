//
//  c.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/18.
//

import Foundation

// Provides a C-compatible definition that aligns with LevelDB's C/C++ structs.
let leveldb_no_compression: UInt8 = 0
let leveldb_snappy_compression: UInt8 = 1

// MARK: - Type definitions

public struct leveldb_t {
    var rep: DB = DB()
}

public struct leveldb_iterator_t {
    var rep: Iterator
}

public struct leveldb_writebatch_t {
    var rep: WriteBatch
}

public struct leveldb_snapshot_t {
    var rep: any Snapshot
}

public struct leveldb_readoptions_t {
    var rep: ReadOptions
}

public struct leveldb_writeoptions_t {
    var rep: WriteOptions
}

public struct leveldb_options_t {
    var rep: Options
}

public struct leveldb_cache_t {
    var rep: (any Cache)?
}

public struct leveldb_seqfile_t {
    var rep: (any SequentialFile)?
}

public struct leveldb_randomfile_t {
    var rep: (any RandomAccessFile)?
}

public struct leveldb_writablefile_t {
    var rep: (any WritableFile)?
}

public struct leveldb_logger_t {
    var rep: (any Logger)?
}

public struct leveldb_filelock_t {
    var rep: (any FileLock)?
}

public class leveldb_comparator_t: Comparator {
    public var state_: UnsafeRawPointer?
    public var destructor: ((UnsafeRawPointer?) -> Void)!
    public var compare_: ((UnsafeRawPointer?, Slice, Slice) -> Int)!
    public var name_: ((UnsafeRawPointer?) -> String)!

    deinit {
        destructor(state_)
    }

    public func Compare(_ a: Slice, _ b: Slice) -> Int {
        return compare_(state_, a, b)
    }

    public func Name() -> String {
        return name_(state_)
    }

    public func FindShortestSeparator(_ start: inout BytesStorage, _ limit: Slice) {}

    public func FindShortSuccessor(_ key: inout BytesStorage) {}
}

public func leveldb_open(_ options: inout leveldb_options_t, _ name: String, _ errptr: String) -> leveldb_t {
    return leveldb_t()
}

public func leveldb_close(_ db: inout leveldb_t) {
}

public func leveldb_put(_ db: inout leveldb_t, _ options: leveldb_writeoptions_t, _ key: String, _ keylen: Int, _ val: String, _ vallen: Int, _ errptr: String) {
}

public func leveldb_delete(_ db: inout leveldb_t, _ options: leveldb_writeoptions_t, _ key: String, _ keylen: Int, _ errptr: String) {
}

public func leveldb_write(_ db: inout leveldb_t, _ options: leveldb_writeoptions_t, _ batch: inout leveldb_writebatch_t, _ errptr: String) {
}
