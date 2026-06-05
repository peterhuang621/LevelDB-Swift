//
//  Table.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public struct Rep {
    public var options: Options
    public var status: Status
    public var file: (any RandomAccessFile)?
    public var cache_id: UInt64
    public var filter: FilterBlockReader
    public var filter_data: [UInt8]

    public var metaindex_handle: BlockHandle
    public var index_block: Block
}

public class Table {
    private var rep_: Rep

    init(_ rep_: Rep) {
        self.rep_ = rep_
    }

    private static func BlockReader(_ arg: UnsafeRawPointer, _ options: ReadOptions, _ index_value: Slice) -> Iterator {
        return Iterator()
    }

    private func InternalGet(_ options: ReadOptions, _ k: Slice, _ arg: UnsafeRawPointer, _ handle_result: (UnsafeRawPointer, Slice, Slice)) -> Status {
        return Status()
    }

    private func ReadMeta(_ footer: Footer) {
    }

    private func ReadFilter(_ filter_handle_value: Slice) {
    }

    public static func Open(_ options: Options, _ file: inout (any RandomAccessFile)?, _ size: UInt64, _ table: inout Table) -> Status {
        table = nil
        if size < Footer.kEncodedLength {
            return Status.Corruption("file is too short to be an sstable")
        }

        var footer_space: [UInt8] = Array(repeating: 0, count: Footer.kEncodedLength)
        var footer_input: Slice = Slice()
        var s = file!.Read(size - UInt64(Footer.kEncodedLength), Footer.kEncodedLength, &footer_input, &footer_space)
        if !s.ok() {
            return s
        }

        var footer: Footer = Footer()
        s = footer.DecodeFrom(&footer_input)
        if !s.ok() {
            return s
        }

        var index_block_contents: BlockContents = BlockContents()
        var opt: ReadOptions = ReadOptions()
        if options.paranoid_checks {
            opt.verify_checksums = true
        }
        s = ReadBlock(file, opt, footer.index_handle, index_block_contents)

        if s.ok() {
//            var index_block: Block = Block(index_block_contents)
        }
        return Status()
    }

    public func NewIterator(_ options: ReadOptions) -> Iterator {
//        return NewTwoLevelIterator(rep_.index_block.NewIterator(rep_.options.comparator),
//                                   &Table.BlockReader, self, options)
        return Iterator()
    }

    public func ApproximateOffsetOf(_ key: Slice) -> UInt64 {
        return 0
    }
}
