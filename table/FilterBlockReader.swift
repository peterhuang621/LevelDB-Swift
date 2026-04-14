//
//  FilterBlockReader.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/12.
//

import Foundation

private let kFilterBaseLg = 11
private let kFilterBase = (1 << kFilterBaseLg)

public class FiterBlockBuilder {
    // MARK: - Private properties, initializers and functions

    private var policy_: (any FilterPolicy)?
    private var keys_: [UInt8] = []
    private var start_: [Int] = []
    private var result_: [UInt8] = []
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

        if num_keys <= tmp_keys_.count {
            tmp_keys_.removeSubrange(num_keys ..< tmp_keys_.count)
        } else {
            tmp_keys_.append(contentsOf: repeatElement(Slice(), count: num_keys - tmp_keys_.count))
        }

        for i in 0 ..< num_keys {
            tmp_keys_[i] = Slice(Array(keys_[start_[i] ..< start_[i + 1]]))
        }

        filter_offsets_.append(UInt32(result_.count))
        policy_!.CreateFilter(&tmp_keys_, num_keys, &result_)

        tmp_keys_.removeAll(keepingCapacity: true)
        keys_.removeAll(keepingCapacity: true)
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
        keys_.append(contentsOf: key.data())
    }

    public func Finish() -> Slice {
        if !start_.isEmpty {
            GenerateFilter()
        }

        let array_offset: UInt32 = UInt32(result_.count)
        for i in 0 ..< filter_offsets_.count {
            PutFixed32(&result_, filter_offsets_[i])
        }

        PutFixed32(&result_, array_offset)
        result_.append(UInt8(kFilterBaseLg))
        return Slice(result_)
    }
}

public class FilterBlockReader {
    private var policy_: (any FilterPolicy)?
    private var data_: Data?
    private var offset_index_: Int
    private var num_: Int
    private var base_lg_: Int

    init(_ policy: (any FilterPolicy)?, _ contents: Slice) {
        policy_ = policy
        data_ = nil
        offset_index_ = 0
        num_ = 0
        base_lg_ = 0

        let n: Int = contents.size()
        if n < 5 {
            return
        }
        base_lg_ = Int(contents[n - 1])
        let last_word: Int = contents.data().withUnsafeBytes {
            Int(DecodeFixed32($0.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: n - 5)))
        }
        if last_word > n - 5 {
            return
        }
        data_ = contents.data()
        offset_index_ = last_word
        num_ = (n - 5 - last_word) / 4
    }

    public func KeyMayMatch(_ block_offset: UInt64, _ key: Slice) -> Bool {
        let index = Int(block_offset >> base_lg_)
        if index < num_ {
            return withUnsafeBytes(of: data_) {
                var ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let start: Int = Int(DecodeFixed32(ptr.advanced(by: offset_index_ + index * 4)))
                let limit: Int = Int(DecodeFixed32(ptr.advanced(by: offset_index_ + index * 4 + 4)))
                if start <= limit && limit <= offset_index_ {
                    let filter: Slice = Slice(ptr.advanced(by: start), limit - start)
                    return policy_!.KeyMayMatch(key, filter)
                } else if start == limit {
                    return false
                }
                // * Missing condition.
                return false
            }
        }
        return true
    }
}
