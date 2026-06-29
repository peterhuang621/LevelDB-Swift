//
//  TableCache.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/30.
//

import Foundation

public class TableCache {
    public func NewIterator(_ options: ReadOptions, _ file_number: UInt64, _ file_size: UInt64, _ tableptr: UnsafeMutablePointer<Table?>? = nil) -> Iterator {
        if tableptr != nil {
            tableptr!.pointee = nil
        }

        let handle: Cache.Handle?
        var s: Status = Status()
//      = FindTable(file_number, file_size, &handle)
        if !s.ok() {
            return NewErrorIterator(s)
        }
//
//      var table :Table= reinterpret_cast < TableAndFile *> (cache_ -> Value(handle)) -> table
        var result: Iterator = Iterator()
//      = table.NewIterator(options)
//        result -> RegisterCleanup(&UnrefEntry, cache_, handle)
//        if tableptr != nullptr {
//            *tableptr = table
//        }
        return result
    }
}
