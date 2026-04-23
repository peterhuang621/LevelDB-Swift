//
//  BlockBuilder.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/23.
//

import Foundation

public class BlockBuilder {
    private var options_: Options
    private var buffer_: [UInt8]
    private var restarts_: [UInt32]
    private var counter_: Int
    private var finished_: Bool
    private var last_key_: [UInt8]

    init(options: Options) {
        options_ = options
        precondition(options.block_restart_interval >= 1, "options.block_restart_interval = \(options.block_restart_interval) should be greater or equal to 1")
        restarts_ = [0]
        counter_ = 0
        finished_ = false
        buffer_ = []
        last_key_ = []
    }

    public func Reset() {
        buffer_.removeAll(keepingCapacity: true)
        restarts_.removeAll(keepingCapacity: true)
        restarts_ = [0]
        counter_ = 0
        finished_ = false
        last_key_.removeAll(keepingCapacity: true)
    }

    public func Add(_ key: Slice, _ value: Slice) {
        let last_key_piece: Slice = Slice(last_key_)
        precondition(!finished_, "finished_ is true")
        precondition(counter_ <= options_.block_restart_interval, "couter = \(counter_) should be less or equal to options_.block_restart_interval = \(options_.block_restart_interval)")
        precondition(buffer_.isEmpty || options_.comparator!.Compare(key, last_key_piece) > 0, "buffer_ should maybe empty or options_ fail to compare, or comparsion result <= 0")
        var shared = 0
        if counter_ < options_.block_restart_interval {
            let min_length: Int = min(last_key_piece.size(), key.size())
            while (shared < min_length) && (last_key_piece[shared] == key[shared]) {
                shared += 1
            }
        } else {
            restarts_.append(UInt32(buffer_.count))
            counter_ = 0
        }

        let non_shared: Int = key.size() - shared

        PutVarint32(&buffer_, UInt32(shared))
        PutVarint32(&buffer_, UInt32(non_shared))
        PutVarint32(&buffer_, UInt32(value.size()))

        buffer_.append(contentsOf: key.data().subdata(in: shared ..< shared + non_shared))
        buffer_.append(contentsOf: value.data())

        last_key_.removeSubrange(shared...)
        last_key_.append(contentsOf: key.data().subdata(in: shared ..< shared + non_shared))
        precondition(Slice(last_key_) == key, "last_key_ is not equal to key")
        counter_ += 1
    }

    public func Finish() -> Slice {
        for i in 0 ..< restarts_.count {
            PutFixed32(&buffer_, restarts_[i])
        }
        PutFixed32(&buffer_, UInt32(restarts_.count))
        finished_ = true
        return Slice(buffer_)
    }

    public func CurrentSizeEstimate() -> Int {
        return buffer_.count + (restarts_.count + 1) * MemoryLayout<UInt32>.stride
    }

    public func empty() -> Bool { return buffer_.isEmpty }
}
