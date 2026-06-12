//
//  Table.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class Table {
    private struct Rep {
        public var options: Options
        public var status: Status
        public var file: (any RandomAccessFile)?
        public var cache_id: UInt64
        public var filter: FilterBlockReader?
        public var filter_data: UnsafePointer<UInt8>?

        public var metaindex_handle: BlockHandle!
        public var index_block: Block!
    }

    private var rep_: Rep

    private init(_ rep_: Rep) {
        self.rep_ = rep_
    }

    private func BlockReader(_ options: ReadOptions, _ index_value: Slice) -> Iterator {
        let block_cache: (any Cache)? = rep_.options.block_cache
        var block: UnsafeMutablePointer<Block>?
        var cache_handle: UnsafeMutablePointer<Cache.Handle>?

        let handle: BlockHandle = BlockHandle()
        var input: Slice = index_value
        var s: Status = handle.DecodeFrom(&input)

        if s.ok() {
            let contents: BlockContents = BlockContents()
            if block_cache != nil {
                let cache_key_buffer: BytesStorage = BytesStorage(16)
                EncodeFixed64(cache_key_buffer, rep_.cache_id)
                EncodeFixed64(cache_key_buffer, handle.offset(), 8)
                let key: Slice = Slice(cache_key_buffer)
                cache_handle = block_cache!.Lookup(key)
                if cache_handle != nil {
                    let val: UnsafeMutableRawPointer = block_cache!.Value(cache_handle)!
                    block = val.assumingMemoryBound(to: Block.self)
                } else {
                    s = ReadBlock(rep_.file, options, handle, contents)
                    if s.ok() {
                        let tmp: Block = Block(contents)
                        block = Unmanaged.passRetained(tmp).toOpaque().assumingMemoryBound(to: Block.self)
                        if contents.cachable && options.fill_cache {
                            cache_handle = block_cache!.Insert(key, block, block!.pointee.size(), DeleteCachedBlock)
                        }
                    }
                }
            } else {
                s = ReadBlock(rep_.file, options, handle, contents)
                if s.ok() {
                    let tmp: Block = Block(contents)
                    block = Unmanaged.passRetained(tmp).toOpaque().assumingMemoryBound(to: Block.self)
                }
            }
        }
        var iter: Iterator!
        if block != nil {
            iter = block!.pointee.NewIterator(rep_.options.comparator)
            if cache_handle == nil {
                iter.RegisterCleanup(DeleteBlock, block, nil)
            } else {
                let cacheRawPtr = Unmanaged.passUnretained(block_cache as AnyObject).toOpaque()
                iter.RegisterCleanup(ReleaseBlock, cacheRawPtr, cache_handle)
            }
        } else {
            iter = NewErrorIterator(s)
        }
        return iter
    }

    private func InternalGet(_ options: ReadOptions, _ k: Slice, _ arg: UnsafeRawPointer, _ handle_result: (UnsafeRawPointer, Slice, Slice) -> Void) -> Status {
        var s: Status = Status()
        let iiter: Iterator = rep_.index_block.NewIterator(rep_.options.comparator)
        iiter.Seek(k)
        if iiter.Valid() {
            var handle_value: Slice = iiter.value()
            let filter: FilterBlockReader? = rep_.filter
            let handle: BlockHandle = BlockHandle()
            if filter != nil && handle
                .DecodeFrom(&handle_value)
                .ok() && !filter!
                .KeyMayMatch(handle.offset(), k) {
                // Not found.
            } else {
                let block_iter: Iterator = BlockReader(options, iiter.value())
                block_iter.Seek(k)
                if block_iter.Valid() {
                    handle_result(arg, block_iter.key(), block_iter.value())
                }
                s = block_iter.status()
            }
        }
        if s.ok() {
            s = iiter.status()
        }
        return s
    }

    private func ReadMeta(_ footer: Footer) {
        if rep_.options.filter_policy == nil {
            return
        }

        var opt: ReadOptions = ReadOptions()
        if rep_.options.paranoid_checks {
            opt.verify_checksums = true
        }
        let contents: BlockContents = BlockContents()
        if !ReadBlock(rep_.file, opt, footer.metaindex_handle(), contents).ok() {
            return
        }
        let meta: Block = Block(contents)

        let iter: Iterator = meta.NewIterator(BytewiseComparator())
        let key: Slice = Slice("filter." + rep_.options.filter_policy!.Name())
        iter.Seek(key)
        if iter.Valid() && iter.key() == key {
            ReadFilter(iter.value())
        }
    }

    private func ReadFilter(_ filter_handle_value: Slice) {
        var v: Slice = filter_handle_value
        let filter_handle: BlockHandle = BlockHandle()
        if !filter_handle.DecodeFrom(&v).ok() {
            return
        }

        var opt: ReadOptions = ReadOptions()
        if rep_.options.paranoid_checks {
            opt.verify_checksums = true
        }
        let block: BlockContents = BlockContents()
        if !ReadBlock(rep_.file, opt, filter_handle, block).ok() {
            return
        }
        if block.heap_allocated {
            rep_.filter_data = block.data.data()
        }
        rep_.filter = FilterBlockReader(rep_.options.filter_policy, block.data)
    }

    public static func Open(_ options: Options, _ file: inout (any RandomAccessFile)?, _ size: UInt64, _ table: inout Table?) -> Status {
        table = nil
        if size < Footer.kEncodedLength {
            return Status.Corruption("file is too short to be an sstable")
        }

        let footer_space: BytesStorage = BytesStorage(Footer.kEncodedLength)
        var footer_input: Slice = Slice()
        var s = file!.Read(size - UInt64(Footer.kEncodedLength), Footer.kEncodedLength, &footer_input, footer_space)
        if !s.ok() {
            return s
        }

        let footer: Footer = Footer()
        s = footer.DecodeFrom(&footer_input)
        if !s.ok() {
            return s
        }

        let index_block_contents: BlockContents = BlockContents()
        var opt: ReadOptions = ReadOptions()
        if options.paranoid_checks {
            opt.verify_checksums = true
        }
        s = ReadBlock(file, opt, footer.index_handle(), index_block_contents)

        if s.ok() {
            let index_block: Block = Block(index_block_contents)
            var rep: Table.Rep!
            rep.options = options
            rep.file = file
            rep.metaindex_handle = footer.metaindex_handle()
            rep.index_block = index_block
            rep.cache_id = ((options.block_cache != nil) ? options.block_cache!.NewId() : 0)
            rep.filter_data = nil
            rep.filter = nil
            table = Table(rep)
            table!.ReadMeta(footer)
        }
        return s
    }

    public func NewIterator(_ options: ReadOptions) -> Iterator {
        return NewTwoLevelIterator(
            rep_.index_block.NewIterator(rep_.options.comparator),
            { opts, indexVal in
                self.BlockReader(opts, indexVal)
            },
            options)
    }

    public func ApproximateOffsetOf(_ key: Slice) -> UInt64 {
        let index_iter: Iterator = rep_.index_block.NewIterator(rep_.options.comparator)
        index_iter.Seek(key)
        var result: UInt64 = 0
        if index_iter.Valid() {
            let handle: BlockHandle = BlockHandle()
            var input: Slice = index_iter.value()
            let s: Status = handle.DecodeFrom(&input)
            if s.ok() {
                result = handle.offset()
            } else {
                result = rep_.metaindex_handle.offset()
            }
        } else {
            result = rep_.metaindex_handle.offset()
        }
        return result
    }
}

fileprivate func DeleteBlock(_ arg: UnsafeRawPointer, _ ignored: UnsafeRawPointer) {
    Unmanaged<Block>.fromOpaque(arg).release()
}

fileprivate func DeleteCachedBlock(_ key: Slice, _ value: UnsafeMutableRawPointer?) {
    // No need to implement under Swift ARC.
}

fileprivate func ReleaseBlock(_ arg: UnsafeRawPointer, _ h: UnsafeRawPointer) {
    let cache: UnsafePointer<Cache> = arg.assumingMemoryBound(to: Cache.self)
    let mutableH = UnsafeMutableRawPointer(mutating: h)
    let handle: UnsafeMutablePointer<Cache.Handle> = mutableH.assumingMemoryBound(to: Cache.Handle.self)
    cache.pointee.Release(handle)
}
