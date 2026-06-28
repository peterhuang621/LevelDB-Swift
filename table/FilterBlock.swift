//
//  FilterBlockReader.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/12.
//

import Foundation

private let kFilterBaseLg = 11
private let kFilterBase = (1 << kFilterBaseLg)

public class FilterBlockBuilder {
    // MARK: - Private properties, initializers and functions

    private var policy_: (any FilterPolicy)?
    private var keys_: BytesStorage = BytesStorage(0)
    private var start_: [Int] = []
    private var result_: BytesStorage = BytesStorage(0)
    private var tmp_keys_: [Slice] = []
    private var filter_offsets_: [UInt32] = []

    init(_ policy: (any FilterPolicy)?) {
        policy_ = policy
    }

    private func GenerateFilter() {
        let num_keys: Int = start_.count
        if num_keys == 0 {
            filter_offsets_.append(UInt32(result_.count))
            return
        }

        start_.append(keys_.count)
        tmp_keys_.resize(newSize: num_keys, repeating: Slice())

        for i in 0 ..< num_keys {
            let base: UnsafePointer<UInt8> = keys_.pointer + start_[i]
            tmp_keys_[i] = Slice(base, start_[i + 1] - start_[i])
        }

        filter_offsets_.append(UInt32(result_.count))
        policy_!.CreateFilter(&tmp_keys_, num_keys, result_)

        tmp_keys_.removeAll(keepingCapacity: true)
        keys_.clear()
        start_.removeAll(keepingCapacity: true)
    }

    // MARK: - Public functions

    public func StartBlock(_ block_offset: UInt64) {
        let filter_index: UInt64 = (block_offset / UInt64(kFilterBase))
        precondition(
            filter_index >= filter_offsets_.count,
            "filter_index = \(filter_index) should be equal or greater than filter_offsets.count = \(filter_offsets_.count)"
        )

        while filter_index > filter_offsets_.count {
            GenerateFilter()
        }
    }

    public func AddKey(_ key: Slice) {
        start_.append(keys_.count)
        keys_.append(key)
    }

    public func Finish() -> Slice {
        if !start_.isEmpty {
            GenerateFilter()
        }

        let array_offset: UInt32 = UInt32(result_.count)
        for item in filter_offsets_ {
            PutFixed32(result_, item)
        }

        PutFixed32(result_, array_offset)
        result_.append(UInt8(kFilterBaseLg))
        return Slice(result_)
    }
}

public class FilterBlockReader {
    private var policy_: (any FilterPolicy)?
    private var data_: UnsafePointer<UInt8>!
    private var offset_: UnsafePointer<UInt8>!
    private var num_: Int
    private var base_lg_: Int

    init(_ policy: (any FilterPolicy)?, _ contents: Slice) {
        policy_ = policy
        num_ = 0
        base_lg_ = 0

        let n: Int = contents.size()
        if n < 5 {
            return
        }
        base_lg_ = Int(contents[n - 1])
        let last_word: UInt32 = DecodeFixed32(contents.data()! + n - 5)
        if Int(last_word) > n - 5 {
            return
        }
        data_ = contents.data()!
        offset_ = data_ + Int(last_word)
        num_ = (n - 5 - Int(last_word)) / 4
    }

    public func KeyMayMatch(_ block_offset: UInt64, _ key: Slice) -> Bool {
        let index: Int = Int(block_offset >> base_lg_)
        if index < num_ {
            let start: UInt32 = DecodeFixed32(offset_ + index * 4)
            let limit: UInt32 = DecodeFixed32(offset_ + index * 4 + 4)
            if start <= limit && limit <= offset_ - data_ {
                let filter: Slice = Slice(data_ + Int(start), Int(limit - start))
                return policy_!.KeyMayMatch(key, filter)
            } else if start == limit {
                return false
            } else {
                return true
            }
        }
        return true
    }
}
