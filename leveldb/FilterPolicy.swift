//
//  FilterPolicy.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/20.
//

import Foundation

public protocol FilterPolicy {
    func Name() -> [UInt8]

    func CreateFilter(_ keys: inout [Slice], _ n: Int, _ dst: inout String)

    func KeyMayMatch(_ key: Slice, _ filter: Slice) -> Bool
}

public func NewBloomFilterPolicy(_ bits_per_key: Int) -> FilterPolicy? {
}
