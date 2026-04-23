//
//  TableBuilder.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/14.
//

import Foundation

public class TableBuilder {
    private struct Rep {
        private var options: Options
        private var index_block_options: Options
        private var file: (any WritableFile)?
        private var offset: UInt64
        private var status: Status = Status()
        private var data_block: BlockBuilder
        private var index_block: BlockBuilder
        private var last_key: [UInt8] = []
        private var num_entries: Int64
        private var closed: Bool
        private var filter_block: FilterBlockBuilder?

        private var pending_index_entry: Bool
        private var pending_handle: BlockHandle = BlockHandle()

        private var compressed_output: [UInt8] = []

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

    private func ok() -> Bool { return status().ok() }

    private func WriteBlock(_ block: BlockBuilder, _ handle: BlockHandle) {
    }

    private func WriteRawBlock(_ data: Slice, _ type: CompressionType, _ handle: BlockHandle) {
    }

    public func ChangeOptions(_ options: Options) -> Status {
    }

    public func Add(_ key: Slice, _ value: Slice) {
    }

    public func Flush() {}

    public func status() -> Status {
    }

    public func Finish() -> Status {
    }

    public func Abandon() {}

    public func NumEntries() -> UInt64 {
    }

    public func FileSize() -> UInt64 {
    }
}
