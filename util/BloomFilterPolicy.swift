//
//  BloomFilterPolicy.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/25.
//

import Foundation

fileprivate func BloomHash(_ key: Slice) -> UInt32 {
    return Hash(key.data()!, key.size(), 0xBC9F1D34)
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

    public func CreateFilter(_ keys: inout [Slice], _ n: Int, _ dst: BytesStorage) {
        var bits: Int = n * Int(bits_per_key_)

        if bits < 64 {
            bits = 64
        }

        let bytes: Int = (bits &+ 7) / 8
        bits = bytes * 8

        let init_size: Int = dst.count
        dst.resize(init_size + bytes)
        dst.append(UInt8(k_))
        let array: UnsafeMutablePointer<UInt8> = dst.mutablepointer + init_size
        for i in 0 ..< n {
            var h: UInt32 = BloomHash(keys[i])
            let delta: UInt32 = ((h >> 17) | (h << 15))
            for _ in 0 ..< k_ {
                let bitpos: UInt32 = h % UInt32(bits)
                array[Int(bitpos) / 8] |= (1 << (bitpos % 8))
                h &+= delta
            }
        }
    }

    public func KeyMayMatch(_ key: Slice, _ bloom_filter: Slice) -> Bool {
        let len: Int = bloom_filter.size()
        if len < 2 {
            return false
        }

        let array: UnsafePointer<UInt8> = bloom_filter.data()!
        let bits: Int = (len - 1) * 8

        let k: Int = Int(array[len - 1])
        if k > 30 {
            return true
        }

        var h: UInt32 = BloomHash(key)
        let delta: UInt32 = ((h >> 17) | (h << 15))
        for _ in 0 ..< k {
            let bitpos: UInt32 = h % UInt32(bits)
            let bitMask = UInt8(1 << (bitpos % 8))
            if (array[Int(bitpos) / 8] & bitMask) == 0 {
                return false
            }
            h &+= delta
        }
        return true
    }
}
