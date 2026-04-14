//
//  Format.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/12.
//

import Foundation

private let kTableMagicNumber: UInt64 = 0xDB4775248B80FB57
private let kBlockTrailerSize: Int = 5

public class BlockHandle {
    private var offset_: UInt64 = 0
    private var size_: UInt64 = 0

    public static let kMaxEncodedLength = 10 + 10

    public var offset: UInt64 { return offset_ }
    public func set_offset(_ offset: UInt64) { offset_ = offset }

    public var size: UInt64 { return size_ }
    public func set_size(_ size: UInt64) { size_ = size }

    public func EncodeTo(_ dst: inout [UInt8]) {
    }

    public func DecodeFrom(_ input: Slice) -> Status {
        var f = Footer()
        f.metaindex_handle.offset_ = 2
        fatalError()
    }
}

public class Footer {
    private var metaindex_handle_: BlockHandle = BlockHandle()
    private var index_handle_: BlockHandle = BlockHandle()

    public static let kEncodedLength = 2 * BlockHandle.kMaxEncodedLength + 8

    public var metaindex_handle: BlockHandle { return metaindex_handle_ }
    public func set_metaindex_handle(_ h: BlockHandle) { metaindex_handle_ = h }

    public var index_handle: BlockHandle { return index_handle_ }
    public func set_index_handle(_ h: BlockHandle) { index_handle_ = h }

    public func EncodeTo(_ dst: inout [UInt8]) {
    }

    public func DecodeFrom(_ input: Slice) -> Status {
        fatalError()
    }
}

public struct BlockContents {
    public var data: Slice
    public var cachable: Bool
    public var heap_allocated: Bool
}

public func ReadBlock(
    _ file: (
        any RandomAccessFile
    )?,
    _ options: ReadOptions,
    _ handle: BlockHandle,
    _ result: BlockContents
) -> Status {
    fatalError()
}
