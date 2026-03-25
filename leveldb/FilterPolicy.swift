//
//  FilterPolicy.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/20.
//

import Foundation

public protocol FilterPolicy {
    func Name() -> String

    func CreateFilter(_ keys: inout [Slice], _ n: Int, _ dst: inout Data)

    func KeyMayMatch(_ key: Slice, _ filter: Slice) -> Bool
}

public func NewBloomFilterPolicy(_ bits_per_key: UInt32) -> FilterPolicy? {
    return BloomFilterPolicy(bits_per_key)
}
