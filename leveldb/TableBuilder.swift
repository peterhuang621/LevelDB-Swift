//
//  TableBuilder.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/14.
//

import Foundation

public class TableBuilder {
    private struct Rep {
        public var options: Options
        public var index_block_options: Options
        public var file: (any WritableFile)?
        public var offset: UInt64
        public var status: Status = Status()
        public var data_block: BlockBuilder
        public var index_block: BlockBuilder
        public var last_key: [UInt8] = []
        public var num_entries: Int64
        public var closed: Bool
        public var filter_block: FilterBlockBuilder?

        public var pending_index_entry: Bool
        public var pending_handle: BlockHandle = BlockHandle()

        public var compressed_output: [UInt8] = []

        init(_ opt: Options, _ f: (any WritableFile)?) {
            options = opt
            index_block_options = opt
            file = f
            offset = 0
            data_block = BlockBuilder(options: opt)
            index_block = BlockBuilder(options: index_block_options)
            num_entries = 0
            closed = false
            filter_block = (opt.filter_policy == nil ? nil : FilterBlockBuilder(opt.filter_policy))

            pending_index_entry = false
            index_block_options.block_restart_interval = 1
        }
    }

    private var rep_: Rep

    init(_ options: Options, _ file: (any WritableFile)?) {
        rep_ = Rep(options, file)
        if let filter_block = rep_.filter_block {
            filter_block.StartBlock(0)
        }
    }

    deinit {
        precondition(rep_.closed, "rep_.closed should be true")
    }

    private func ok() -> Bool { return status().ok() }

    private func WriteBlock(_ block: BlockBuilder, _ handle: BlockHandle) {
        precondition(ok())

    }

    private func WriteRawBlock(_ data: Slice, _ type: CompressionType, _ handle: BlockHandle) {
    }

    public func ChangeOptions(_ options: Options) -> Status {
        if options.comparator !== rep_.options.comparator {
            return Status.InvalidArgument(Slice("changing comparartor while building table"))
        }

        rep_.options = options
        rep_.index_block_options = options
        rep_.index_block_options.block_restart_interval = 1
        return Status.OK()
    }

    public func Add(_ key: Slice, _ value: Slice) {
        precondition(!rep_.closed, "rep_.closed should be false")
        if !ok() {
            return
        }
        if rep_.num_entries > 0 {
            precondition(rep_.options.comparator!.Compare(key, Slice(rep_.last_key)) > 0, "comparsion between key and rep_.last_key is greater than 0")
        }

        if rep_.pending_index_entry {
            precondition(rep_.data_block.empty(), "rep_.data_block is not empty")
            rep_.options.comparator?.FindShortestSeparator(&rep_.last_key, key)
            var handle_encoding: [UInt8] = []
            rep_.pending_handle.EncodeTo(&handle_encoding)
            rep_.index_block.Add(Slice(rep_.last_key), Slice(handle_encoding))
            rep_.pending_index_entry = false
        }

        if let filter_block = rep_.filter_block {
            filter_block.AddKey(key)
        }

        rep_.last_key = key.ToInt8Array()
        rep_.num_entries += 1
        rep_.data_block.Add(key, value)

        let estimated_block_size: Int = rep_.data_block.CurrentSizeEstimate()
        if estimated_block_size >= rep_.options.block_size {
            Flush()
        }
    }

    public func Flush() {
        precondition(!rep_.closed, "rep_.closed should be false")
        if !ok() {
            return
        }
        if rep_.data_block.empty() {
            return
        }
        precondition(!rep_.pending_index_entry, "rep_.pending_index_entry should be false")
        WriteBlock(rep_.data_block, rep_.pending_handle)
        if ok() {
            rep_.pending_index_entry = true
            rep_.status = rep_.file!.Flush()
        }
        if let filter_block = rep_.filter_block {
            filter_block.StartBlock(rep_.offset)
        }
    }

    public func status() -> Status {
        return rep_.status
    }
//
//    public func Finish() -> Status {
//    }
//
//    public func Abandon() {}
//
//    public func NumEntries() -> UInt64 {
//    }
//
//    public func FileSize() -> UInt64 {
//    }
}
