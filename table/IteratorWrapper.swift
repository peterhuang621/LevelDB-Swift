//
//  IteratorWrapper.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class IteratorWrapper {
    // MARK: - Private properties, initializers and functions

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

    // MARK: - Public functions

    public func iter() -> Iterator? {
        return iter_
    }

    public func Set(_ iter: Iterator?) {
        iter_ = iter
        if iter_ == nil {
            valid_ = false
        } else {
            Update()
        }
    }

    public func Valid() -> Bool { return valid_ }

    public func key() -> Slice {
        precondition(Valid(), "IteratorWrapper is invalid")
        return key_
    }

    public func value() -> Slice {
        precondition(Valid(), "IteratorWrapper is invalid")
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        return iter_.value()
    }

    public func status() -> Status {
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        return iter_.status()
    }

    public func Next() {
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        iter_.Next()
        Update()
    }

    public func Prev() {
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        iter_.Prev()
        Update()
    }

    public func Seek(_ k: Slice) {
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        iter_.Seek(k)
        Update()
    }

    public func SeekToFirst() {
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        iter_.SeekToFirst()
        Update()
    }

    public func SeekToLast() {
        guard let iter_ = iter_ else { fatalError("iter_ is nil") }
        iter_.SeekToLast()
        Update()
    }
}
