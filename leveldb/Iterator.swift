//
//  Iterator.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/11.
//

import Foundation

public class Iterator {
    // MARK: - Private properties

    private class CleanupNode {
        public var function: CleanupFunction?
        public var arg1: UnsafeRawPointer?
        public var arg2: UnsafeRawPointer?
        public var next: CleanupNode?

        public func IsEmpty() -> Bool {
            return function == nil
        }

        public func Run() {
            function?(arg1!, arg2!)
        }

        deinit {
            Run()
        }
    }

    private var cleanup_head_ = CleanupNode()

    // MARK: - Public definitions and functions

    public typealias CleanupFunction = (UnsafeRawPointer, UnsafeRawPointer) -> Void

    public func Valid() -> Bool {
        fatalError("must be override")
    }

    public func SeekToFirst() {
        fatalError("must be override")
    }

    public func SeekToLast() {
        fatalError("must be override")
    }

    public func Seek(_ target: Slice) {
        fatalError("must be override")
    }

    public func Next() {
        fatalError("must be override")
    }

    public func Prev() {
        fatalError("must be override")
    }

    public func key() -> Slice {
        fatalError("must be override")
    }

    public func value() -> Slice {
        fatalError("must be override")
    }

    public func status() -> Status {
        fatalError("must be override")
    }

    public func RegisterCleanup(_ function: CleanupFunction?, _ arg1: UnsafeRawPointer, _ arg2: UnsafeRawPointer) {
        precondition(function != nil, "function is nil")

        if cleanup_head_.IsEmpty() {
            cleanup_head_.function = function
            cleanup_head_.arg1 = arg1
            cleanup_head_.arg2 = arg2
        } else {
            var node = CleanupNode()
            node.function = function
            node.arg1 = arg1
            node.arg2 = arg2

            node.next = cleanup_head_.next
            cleanup_head_.next = node
        }
    }
}

public class EmptyIterator: Iterator {
    private var status_: Status

    init(_ s: Status) {
        status_ = s
    }

    override public func Valid() -> Bool { return false }

    override public func Seek(_ target: Slice) {}

    override public func SeekToFirst() {}

    override public func SeekToLast() {}

    override public func Next() {
        fatalError("EmptyIterator has no Next Iterator")
    }

    override public func Prev() {
        fatalError("EmptyIterator has no Prev Iterator")
    }

    override public func key() -> Slice {
        fatalError("EmptyIterator has no key Iterator")
    }

    override public func status() -> Status { return status_ }
}

public func NewEmptyIterator() -> Iterator {
    return EmptyIterator(Status.OK())
}

public func NewErrorIterator(_ status: Status) -> Iterator {
    return EmptyIterator(status)
}
