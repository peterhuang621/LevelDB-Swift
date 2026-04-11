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
//    private var rep_: Rep

    public static func Open(_ options: Options, _ file: inout (any RandomAccessFile)?, _ size: UInt64, _ table: inout Table) -> Status {
        return Status()
    }

    public func NewIterator(_ options: ReadOptions) -> Iterator {
//        return NewTwoLevelIterator(rep_.index_block.NewIterator(rep_.options.comparator),
//                                   &Table.BlockReader, self, options)
        return Iterator()
    }

    private static func BlockReader(_ arg: UnsafeRawPointer, _ options: ReadOptions, _ index_value: Slice) -> Iterator {
        return Iterator()
    }
}
