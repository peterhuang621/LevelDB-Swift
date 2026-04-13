//
//  Options.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public enum CompressionType: UInt8 {
    case kNoCompression = 0x0
    case kSnappyCompression = 0x1
    case kZstdCompression = 0x2
}

public struct Options {
    public var comparator: (any Comparator)? = BytewiseComparator()
    public var create_if_missing = false
    public var error_if_exists = false
    public var paranoid_checks = false
    public var env: Env = Env.Default()
    public var info_log: (any Logger)?
    public var write_buffer_size: Int = 4 * 1024 * 1024
    public var max_open_files: Int = 1000
    public var block_cache: (any Cache)?
    public var block_size: Int = 4 * 1024
    public var block_restart_interval: Int = 16
    public var max_file_size: Int = 2 * 1024 * 1024
    public var compression: CompressionType = .kSnappyCompression
    public var zstd_compression_level: Int = 1
    public var reuse_logs = false
    public var filter_policy: (any FilterPolicy)?
}

public struct ReadOptions {
    var verify_checksums = false
    var fill_cache = true
    var snapshot: (any Snapshot)?
}

public struct WriteOptions {
    var sync = false
}
