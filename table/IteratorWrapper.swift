//
//  IteratorWrapper.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class IteratorWrapper {
    private var iter_: Iterator?
    private var valid_: Bool
    private var key_: Slice

    private func Update() {
        valid_ = iter_!.Valid()
        if valid_ {
            key_ = iter_!.key()
        }
    }

    init() {
        iter_ = nil
        valid_ = false
        key_ = Slice()
    }

    init(_ iter: Iterator?) {
        iter_ = nil
        valid_ = false
        key_ = Slice()
        Set(iter)
    }

    public func Set(_ iter: Iterator?) {
        iter_ = iter
        if iter_ == nil {
            valid_ = false
        } else {
            Update()
        }
    }
}
