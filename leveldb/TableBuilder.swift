//
//  TableBuilder.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/14.
//

import Foundation

public class TableBuilder {
    private class Rep {
        public var options: Options
        public var index_block_options: Options
        public var file: (any WritableFile)?
        public var offset: UInt64
        public var status: Status = Status()
        public var data_block: BlockBuilder
        public var index_block: BlockBuilder
        public var last_key: BytesStorage = BytesStorage(0)
        public var num_entries: Int64
        public var closed: Bool
        public var filter_block: FilterBlockBuilder?

        public var pending_index_entry: Bool
        public var pending_handle: BlockHandle = BlockHandle()

        public var compressed_output: BytesStorage = BytesStorage(0)

        init(_ opt: Options, _ f: (any WritableFile)?) {
            options = opt
            index_block_options = opt
            file = f
            offset = 0
            data_block = BlockBuilder(opt)
            index_block = BlockBuilder(index_block_options)
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
        let r: Rep = rep_
        let raw: Slice = block.Finish()

        var block_contents: Slice = Slice()
        let type: CompressionType = r.options.compression
        switch type {
        case .kNoCompression:
            block_contents = raw

        case .kSnappyCompression:
            print("not implement for Snappy Compression")

        case .kZstdCompression:
            print("not implement for Zstd Compression")
        }
        WriteRawBlock(block_contents, type, handle)
        r.compressed_output.clear()
        block.Reset()
    }

    private func WriteRawBlock(_ block_contents: Slice, _ type: CompressionType, _ handle: BlockHandle) {
        let r: Rep = rep_
        handle.set_offset(r.offset)
        handle.set_size(UInt64(block_contents.size()))
        r.status = r.file!.Append(block_contents)
        if r.status.ok() {
            let trailer: BytesStorage = BytesStorage(kBlockTrailerSize)
            trailer[0] = type.rawValue
            var crc: UInt32 = Value(block_contents.data()!, block_contents.size())
            crc = Extend(crc, trailer.pointer, 1)
            EncodeFixed32(trailer, Mask(crc), 1)
            r.status = r.file!.Append(Slice(trailer, kBlockTrailerSize))
            if r.status.ok() {
                r.offset += UInt64(block_contents.size() + kBlockTrailerSize)
            }
        }
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
            let handle_encoding: BytesStorage = BytesStorage(0)
            rep_.pending_handle.EncodeTo(handle_encoding)
            rep_.index_block.Add(Slice(rep_.last_key), Slice(handle_encoding))
            rep_.pending_index_entry = false
        }

        if let filter_block = rep_.filter_block {
            filter_block.AddKey(key)
        }

        rep_.last_key = BytesStorage(key)
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

    public func Finish() -> Status {
        let r: Rep = rep_
        Flush()
        precondition(!r.closed, "r.close should be false")
        r.closed = true

        let filter_block_handle: BlockHandle = BlockHandle()
        let metaindex_block_handle: BlockHandle = BlockHandle()
        let index_block_handle: BlockHandle = BlockHandle()

        if ok() && r.filter_block != nil {
            WriteRawBlock(r.filter_block!.Finish(), .kNoCompression, filter_block_handle)
        }

        if ok() {
            let meta_index_block: BlockBuilder = BlockBuilder(r.options)
            if r.filter_block != nil {
                let key: Slice = Slice("filter" + (r.options.filter_policy?.Name() ?? ""))
                let handle_encoding: BytesStorage = BytesStorage(0)
                filter_block_handle.EncodeTo(handle_encoding)
                meta_index_block.Add(key, Slice(handle_encoding))
            }
            WriteBlock(meta_index_block, metaindex_block_handle)
        }

        if ok() {
            if r.pending_index_entry {
                r.options.comparator?.FindShortSuccessor(&r.last_key)
                let handle_encoding: BytesStorage = BytesStorage(0)
                r.pending_handle.EncodeTo(handle_encoding)
                r.index_block.Add(Slice(r.last_key), Slice(handle_encoding))
                r.pending_index_entry = false
            }
            WriteBlock(r.index_block, index_block_handle)
        }

        if ok() {
            let footer: Footer = Footer()
            footer.set_metaindex_handle(metaindex_block_handle)
            footer.set_index_handle(index_block_handle)
            let footer_encoding: BytesStorage = BytesStorage(0)
            footer.EncodeTo(footer_encoding)
            r.status = r.file!.Append(Slice(footer_encoding))
            if r.status.ok() {
                r.offset += UInt64(footer_encoding.count)
            }
        }

        return r.status
    }

    public func Abandon() {
        let r: Rep = rep_
        precondition(!r.closed, "r.closed should be false")
        r.closed = true
    }

    public func NumEntries() -> UInt64 { return UInt64(rep_.num_entries) }

    public func FileSize() -> UInt64 { return rep_.offset }
}
