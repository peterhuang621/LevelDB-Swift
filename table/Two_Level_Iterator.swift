//
//  Two_Level_Iterator.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public typealias BlockFunction = (UnsafeRawPointer, ReadOptions, Slice) -> Iterator

public class TwoLevelIterator: Iterator {
    // MARK: - Private properties, initializers and functions

    private var block_function_: BlockFunction
    private var arg_: UnsafeRawPointer
    private let options_: ReadOptions
    private var status_: Status
    private var index_iter_: IteratorWrapper
    private var data_iter_: IteratorWrapper
    private var data_block_handle_: Slice

    init(
        _ index_iter: Iterator?,
        _ block_function_: @escaping BlockFunction,
        _ arg_: UnsafeRawPointer,
        _ options_: ReadOptions,
    ) {
        self.block_function_ = block_function_
        self.arg_ = arg_
        self.options_ = options_
        status_ = Status()
        index_iter_ = IteratorWrapper(index_iter)
        data_iter_ = IteratorWrapper(nil)
        data_block_handle_ = Slice()
    }

    private func SaveError(_ s: Status) {
        if status_.ok() && !s.ok() {
            status_ = s
        }
    }

    private func SkipEmptyDataBlocksForward() {
        while data_iter_.iter() == nil || !data_iter_.Valid() {
            if !index_iter_.Valid() {
                SetDataIterator(nil)
                return
            }
            index_iter_.Next()
            InitDataBlock()
            if data_iter_.iter() != nil {
                data_iter_.SeekToFirst()
            }
        }
    }

    private func SkipEmptyDataBlocksBackward() {
        while data_iter_.iter() == nil || !data_iter_.Valid() {
            if !index_iter_.Valid() {
                SetDataIterator(nil)
                return
            }
            index_iter_.Prev()
            InitDataBlock()
            if data_iter_.iter() != nil {
                data_iter_.SeekToLast()
            }
        }
    }

    private func SetDataIterator(_ data_iter: Iterator?) {
        if data_iter_.iter() != nil {
            SaveError(data_iter_.status())
        }
        data_iter_.Set(data_iter)
    }

    private func InitDataBlock() {
        if index_iter_.Valid() {
            let handle: Slice = index_iter_.value()
            if data_iter_.iter() != nil && handle.compare(data_block_handle_) == 0 {
                // No need to change anything
            } else {
                let iter: Iterator = block_function_(arg_, options_, handle)
                data_block_handle_ = handle
                SetDataIterator(iter)
            }
        } else {
            SetDataIterator(nil)
        }
    }

    // MARK: - Public functions

    override public func Seek(_ target: Slice) {
        index_iter_.Seek(target)
        InitDataBlock()
        if data_iter_.iter() != nil {
            data_iter_.Seek(target)
        }
        SkipEmptyDataBlocksForward()
    }

    override public func SeekToFirst() {
        index_iter_.SeekToFirst()
        InitDataBlock()
        if data_iter_.iter() != nil {
            data_iter_.SeekToFirst()
        }
        SkipEmptyDataBlocksForward()
    }

    override public func SeekToLast() {
        index_iter_.SeekToLast()
        InitDataBlock()
        if data_iter_.iter() != nil {
            data_iter_.SeekToLast()
        }
        SkipEmptyDataBlocksBackward()
    }

    override public func Next() {
        precondition(Valid())
        data_iter_.Next()
        SkipEmptyDataBlocksForward()
    }

    override public func Prev() {
        precondition(Valid())
        data_iter_.Prev()
        SkipEmptyDataBlocksBackward()
    }

    override public func Valid() -> Bool { return data_iter_.Valid() }

    override public func key() -> Slice {
        precondition(Valid())
        return data_iter_.key()
    }

    override public func value() -> Slice {
        precondition(Valid())
        return data_iter_.value()
    }

    override public func status() -> Status {
        if !index_iter_.status().ok() {
            return index_iter_.status()
        } else if data_iter_.iter() != nil && !data_iter_.status().ok() {
            return data_iter_.status()
        } else {
            return status_
        }
    }
}

public func NewTwoLevelIterator(_ index_iter: Iterator?, _ block_function: @escaping BlockFunction, _ arg: UnsafeRawPointer, _ options: ReadOptions) -> Iterator {
    return TwoLevelIterator(index_iter, block_function, arg, options)
}
