//
//  Random.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/17.
//

import Foundation

public class Random {
    private var seed_: UInt32
    private static let M: UInt32 = 2147483647
    private static let A: UInt64 = 16807

    init(_ s: UInt32) {
        seed_ = (s & 0x7FFFFFFF)
        if seed_ == 0 || seed_ == 2147483647 {
            seed_ = 1
        }
    }

    public func Next() -> UInt32 {
        let product: UInt64 = UInt64(seed_) * Random.A
        seed_ = UInt32((product >> 31) + (product & UInt64(Random.M)))
        if seed_ > Random.M {
            seed_ -= Random.M
        }
        return seed_
    }

    public func Uniform(_ n: Int) -> UInt32 { return Next() % UInt32(n) }

    public func OneIn(_ n: Int) -> Bool { return (Next() % UInt32(n)) == 0 }

    public func Skewed(_ max_log: Int) -> UInt32 { return Uniform(1 << Uniform(max_log + 1)) }
}
