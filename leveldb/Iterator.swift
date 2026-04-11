//
//  Iterator.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class Iterator {
    public func Valid() -> Bool {
        fatalError("must be override")
    }

    public func key() -> Slice {
        fatalError("must be override")
    }
}
