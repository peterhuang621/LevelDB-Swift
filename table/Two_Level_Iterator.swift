//
//  Two_Level_Iterator.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public typealias BlockFunction = (UnsafeRawPointer, ReadOptions, Slice) -> Iterator

public class TwoLevelIterator: Iterator {
    private var block_function_: BlockFunction
    private var arg_: UnsafeRawPointer
    private let options_: ReadOptions
    private var status_: Status
    private var index_iter_: IteratorWrapper
    private var data_iter_: IteratorWrapper?
    private var data_block_handle_: String

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
        data_iter_ = nil
        data_block_handle_ = ""
    }
}

public func NewTwoLevelIterator(_ index_iter: Iterator?, _ block_function: @escaping BlockFunction, _ arg: UnsafeRawPointer, _ options: ReadOptions) -> Iterator {
    return TwoLevelIterator(index_iter, block_function, arg, options)
}
