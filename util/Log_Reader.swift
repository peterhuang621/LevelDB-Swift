//
//  Log_Reader.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/26.
//

import Foundation

public class Reader {
    public protocol Reporter {
    }

    private let file_: SequentialFile?
    private let reporter_: Reporter?
    private var checksum_: Bool
    private let backing_store_: [UInt8] = Array(repeating: 0, count: kBlockSize)
    private var buffer_: Slice = Slice()
    private var eof_: Bool = false

    private var last_record_offset_: UInt64 = 0
    private var end_of_buffer_offset_: UInt64 = 0
    private var initial_offset_: UInt64
    private var resyncing_: Bool

    private enum ReaderRecordType: Int {
        case kEof = 5 // (kMaxRecordType + 1)
        case kBadRecord = 6 // (kMaxRecordType + 2)
    }

    init(
        _ file: SequentialFile?,
        _ reporter: Reporter?,
        _ checksum: Bool,
        _ initial_offset: UInt64
    ) {
        file_ = file
        reporter_ = reporter
        checksum_ = checksum
        initial_offset_ = initial_offset
        resyncing_ = (initial_offset > 0)
    }

    //  private func SkipToInitialBlock()->Bool{
//
    //  }
//
    //  private func ReadPhysicalRecord(_ result:inout Slice)->UInt{
//
    //  }
//
    //  private func ReportCorruption(_ bytes:UInt64, _ reason:[UInt8]){
//
    //  }
//
    //  private func ReportDrop(_ bytes:UInt64, _ reason:Status){
//
    //  }
}
