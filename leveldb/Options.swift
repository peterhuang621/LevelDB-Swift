//
//  Options.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class Options {
}

public struct ReadOptions {
    var verify_checksums = false
    var fill_cache = true
    var snapshot: (any Snapshot)?
}

public struct WriteOptions {
    var sync = false
}
