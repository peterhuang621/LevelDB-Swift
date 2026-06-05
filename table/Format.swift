//
//  Format.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/12.
//

import Foundation

public let kTableMagicNumber: UInt64 = 0xDB4775248B80FB57
public let kBlockTrailerSize: Int = 5

public class BlockHandle {
    private var offset_: UInt64 = 0
    private var size_: UInt64 = 0

    public static let kMaxEncodedLength = 10 + 10

    public var offset: UInt64 { return offset_ }
    public func set_offset(_ offset: UInt64) { offset_ = offset }

    public var size: UInt64 { return size_ }
    public func set_size(_ size: UInt64) { size_ = size }

    public func EncodeTo(_ dst: inout [UInt8]) {
        precondition(offset_ != 0)
        precondition(size_ != 0)
        PutVarint64(&dst, offset_)
        PutVarint64(&dst, size_)
    }

    public func DecodeFrom(_ input: Slice) -> Status {
        var inp = input
        if GetVarint64(&inp, &offset_) && GetVarint64(&inp, &size_) {
            return Status.OK()
        } else {
            return Status.Corruption("bad block handle")
        }
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
        let original_size: Int = dst.count
        metaindex_handle_.EncodeTo(&dst)
        index_handle_.EncodeTo(&dst)
        dst.resize(newSize: 2 * BlockHandle.kMaxEncodedLength, repeating: 0)
        PutFixed32(&dst, UInt32(kTableMagicNumber) & 0xFFFFFFFF)
        PutFixed32(&dst, UInt32(kTableMagicNumber >> 32))
        precondition(dst.count == original_size + Footer.kEncodedLength)
    }

    public func DecodeFrom(_ input: inout Slice) -> Status {
        if input.size() < Footer.kEncodedLength {
            return Status.Corruption("not an sstable (footer too short)")
        }

        var magic: UInt64 = 0
        input.data().withUnsafeBytes {
            let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(
                by: Footer.kEncodedLength - 8)
            let magic_lo: UInt64 = UInt64(DecodeFixed32(ptr))
            let magic_hi: UInt64 = UInt64(DecodeFixed32(ptr.advanced(by: 4)))
            magic = ((magic_hi << 32) | magic_lo)
        }
        if magic != kTableMagicNumber {
            return Status.Corruption("not an sstable (bad magic number)")
        }

        var result: Status = metaindex_handle_.DecodeFrom(input)
        if result.ok() {
            result = index_handle_.DecodeFrom(input)
        }
        if result.ok() {
            input = Slice(input.data().suffix(from: Footer.kEncodedLength))
        }
        return result
    }
}

public class BlockContents {
    public var data: Slice = Slice()
    public var cachable: Bool = true
    public var heap_allocated: Bool = true
}

public func ReadBlock(
    _ file: (
        any RandomAccessFile
    )?,
    _ options: ReadOptions,
    _ handle: BlockHandle,
    _ result: BlockContents
) -> Status {
    result.data = Slice()
    result.cachable = false
    result.heap_allocated = false

    let n: Int = Int(handle.size)
    var buf: [UInt8] = Array(repeating: 0, count: n + kBlockTrailerSize)
    var contents: Slice = Slice()
    var s: Status = file!.Read(handle.offset, n + kBlockTrailerSize, &contents, &buf)
    if !s.ok() {
        return s
    }
    if contents.size() != n + kBlockTrailerSize {
        return Status.Corruption("truncated block read")
    }

    var data: [UInt8] = [UInt8](contents.data())
    if options.verify_checksums {
        var actual: UInt32 = 0
        let crc: UInt32 = data.withUnsafeBytes {
            let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
            actual = Value(ptr, n + 1)
            return Unmask(DecodeFixed32(ptr.advanced(by: n + 1)))
        }

        if actual != crc {
            s = Status.Corruption("block checksum mismatch")
            return s
        }
    }

    switch CompressionType(rawValue: data[n]) {
    case .kNoCompression:
        if data != buf {
            result.data = Slice(data, n)
            result.heap_allocated = false
            result.cachable = false
        }
    case .kSnappyCompression:
        print("kSnappyCompression way is not implenmented")
    case .kZstdCompression:
        print("kZstdCompression way is not implenmented")
    default:
        return Status.Corruption("bad block type")
    }

    return Status.OK()
}
