//
//  BloomFilterPolicy.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/25.
//

import Foundation

fileprivate func BloomHash(_ key: Slice) -> UInt32 {
    return Hash(key.data().withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, key.size(), 0xBC9F1D34)
}

public class BloomFilterPolicy: FilterPolicy {
    private var bits_per_key_: UInt32
    private var k_: UInt32 = 0

    init(_ bits_per_key_: UInt32) {
        self.bits_per_key_ = bits_per_key_
        k_ = UInt32(Double(bits_per_key_) * 0.69)

        if k_ < 1 {
            k_ = 1
        }
        if k_ > 30 {
            k_ = 30
        }
    }

    public func Name() -> String {
        return "leveldb.BuiltinBloomFilter2"
    }

    public func CreateFilter(_ keys: inout [Slice], _ n: Int, _ dst: inout Data) {
        var bits: UInt32 = UInt32(n) * bits_per_key_

        if bits < 64 {
            bits = 64
        }

        var bytes = (bits &+ 7) / 8
        bits = bytes * 8

        let init_size = dst.count
        dst.reserveCapacity(init_size + Int(bytes))
        dst.append(UInt8(k_))

        dst.withUnsafeMutableBytes {
            let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let array = ptr.advanced(by: init_size)

            for i in 0 ..< n {
                var h = BloomHash(keys[i])
                let delta = ((h >> 17) | (h << 15))
                for j in 0 ..< k_ {
                    let bitpos = h % bits
                    array[Int(bitpos) / 8] |= (1 << (bitpos % 8))
                    h &+= delta
                }
            }
        }
    }

    public func KeyMayMatch(_ key: Slice, _ bloom_filter: Slice) -> Bool {
        let len = bloom_filter.size()
        if len < 2 {
            return false
        }

        let array = bloom_filter.data()
        let bits = UInt32(len - 1) * 8

        let k = array[len - 1]
        if k > 30 {
            return true
        }

        var h = BloomHash(key)
        let delta = ((h >> 17) | (h << 15))
        for _ in 0 ..< k {
            let bitpos = h % bits
            let byteIndex = Int(bitpos / 8)
            let bitMask = UInt8(1 << (bitpos % 8))
            if (array[byteIndex] & bitMask) == 0 {
                return false
            }
            h &+= delta
        }
        return true
    }
}
