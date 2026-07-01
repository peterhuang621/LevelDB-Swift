//
//  VersionSet.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/6/28.
//

import Foundation

public func FindFile(_ icmp: InternalKeyComparator, _ files: Array<FileMetaData>, _ key: Slice) -> Int {
    var left: Int = 0
    var right: Int = files.count
    while left < right {
        let mid: Int = (left + right) / 2
        let f: FileMetaData = files[mid]
        if icmp.Compare(f.largest.Encode(), key) < 0 { left = mid + 1 } else { right = mid }
    }
    return right
}

fileprivate func AfterFile(_ ucmp: Comparator, _ user_key: Slice?, _ f: FileMetaData) -> Bool {
    return user_key != nil && (ucmp.Compare(user_key!, f.largest.user_key()) > 0)
}

fileprivate func BeforeFile(_ ucmp: Comparator, _ user_key: Slice?, _ f: FileMetaData) -> Bool {
    return user_key != nil && (ucmp.Compare(user_key!, f.smallest.user_key()) < 0)
}

public func SomeFileOverlapsRange(_ icmp: InternalKeyComparator, _ disjoint_sorted_files: Bool, _ files: Array<FileMetaData>, _ smallest_user_key: Slice?, _ largest_user_key: Slice?) -> Bool {
    let ucmp: Comparator = icmp.user_comparator()!
    if !disjoint_sorted_files {
        for f in files {
            if AfterFile(ucmp, smallest_user_key, f) || BeforeFile(ucmp, largest_user_key, f) {} else { return true }
        }
        return false
    }

    var index: Int = 0
    if let skey = smallest_user_key {
        let small_key: InternalKey = InternalKey(
            skey,
            SequenceNumber(kMaxSequenceNumber),
            kValueTypeForSeek
        )
        index = FindFile(icmp, files, small_key.Encode())
    }

    if index >= files.count { return false }
    return !BeforeFile(ucmp, largest_user_key, files[index])
}

fileprivate func FindFile(_ icmp: InternalKeyComparator, _ files: Array<FileMetaData?>, _ key: Slice) -> Int {
    var left: Int = 0
    var right: Int = files.count
    while left < right {
        let mid: Int = (left + right) / 2
        let f: FileMetaData = files[mid]!
        if icmp.Compare(f.largest.Encode(), key) < 0 {
            left = mid + 1
        } else {
            right = mid
        }
    }
    return right
}

fileprivate func GetFileIterator(_ options: ReadOptions, _ cache_: TableCache, _ file_value: Slice) -> Iterator {
    let cache: TableCache = cache_
    if file_value.size() != 16 {
        return NewErrorIterator(Status.Corruption("FileReader invoked with unexpected value"))
    } else {
        return cache.NewIterator(options, DecodeFixed64(file_value.data()!), DecodeFixed64(file_value.data()! + 8))
    }
}

fileprivate func NewestFirst(_ a: FileMetaData?, _ b: FileMetaData?) -> Bool { return a!.number > b!.number }

fileprivate enum SaverState {
    case kNotFound
    case kFound
    case kDeleted
    case kCorrupt
}

fileprivate struct Saver {
    var state: SaverState
    var ucmp: Comparator
    var user_key: Slice
    var value: BytesStorage
}

fileprivate func SaveValue(_ arg: Saver, _ ikey: Slice, _ v: Slice) {
    var s: Saver = arg
    var parsed_key: ParsedInternalKey = ParsedInternalKey()
    if !ParseInternalKey(ikey, &parsed_key) {
        s.state = .kCorrupt
    } else {
        if s.ucmp.Compare(parsed_key.user_key, s.user_key) == 0 {
            s.state = (parsed_key.type == .kTypeValue) ? .kFound : .kDeleted
            if s.state == .kFound {
                s.value.append(v)
            }
        }
    }
}

public class Version {
    private class LevelFileNumIterator: Iterator {
        private var icmp_: InternalKeyComparator
        private let flist_: Array<FileMetaData?>
        private var index_: Int
        private var value_buf_: BytesStorage = BytesStorage(16)

        init(_ icmp: InternalKeyComparator, _ flist: Array<FileMetaData?>) {
            icmp_ = icmp
            flist_ = flist
            index_ = flist.count
        }

        override public func Valid() -> Bool { return index_ < flist_.count }

        override public func Seek(_ target: Slice) { index_ = FindFile(icmp_, flist_, target) }

        override public func SeekToFirst() { index_ = 0 }

        override public func SeekToLast() { index_ = flist_.isEmpty ? 0 : flist_.count - 1 }

        override public func Next() {
            precondition(Valid())
            index_ += 1
        }

        override public func Prev() {
            precondition(Valid())
            if index_ == 0 {
                index_ = flist_.count
            } else {
                index_ -= 1
            }
        }

        override public func key() -> Slice {
            precondition(Valid())
            return flist_[index_]!.largest.Encode()
        }

        override public func value() -> Slice {
            precondition(Valid())
            EncodeFixed64(value_buf_, flist_[index_]!.number)
            EncodeFixed64(value_buf_, flist_[index_]!.file_size, 8)
            return Slice(value_buf_)
        }

        override public func status() -> Status { return Status.OK() }
    }

    public var vset_: VersionSet
    private var next_: Version!
    private var prev_: Version!
    private var refs_: Int
    public var files_: [7 of Array<FileMetaData?>] = InlineArray(repeating: Array<FileMetaData?>())
    private var file_to_compact_: FileMetaData?
    private var file_to_compact_level_: Int
    private var compaction_score_: Double
    private var compaction_level_: Int

    fileprivate init(_ vset: VersionSet) {
        vset_ = vset
        refs_ = 0
        file_to_compact_ = nil
        file_to_compact_level_ = -1
        compaction_score_ = -1
        compaction_level_ = -1
        next_ = self
        next_ = self
    }

    private func NewConcatenatingIterator(_ options: ReadOptions, _ level: Int) -> Iterator {
        let cache: TableCache = vset_.table_cache_
        return NewTwoLevelIterator(
            LevelFileNumIterator(vset_.icmp_, files_[level]),
            { opts, fileValue in
                GetFileIterator(opts, cache, fileValue) },
            options)
    }

    private func ForEachOverlapping(
        _ user_key: Slice,
        _ internal_key: Slice,
        _ fc: (Int, FileMetaData) -> Bool
    ) {
        let ucmp: (any Comparator)? = vset_.icmp_.user_comparator()
        var tmp: Array<FileMetaData?> = Array(repeating: nil, count: files_[0].count)
        for i in 0 ..< files_[0].count {
            let f: FileMetaData = files_[0][i]!
            if (ucmp!.Compare(user_key, f.smallest.user_key()) >= 0) && (ucmp!.Compare(user_key, f.largest.user_key()) <= 0) {
                tmp.append(f)
            }
        }

        if !tmp.isEmpty {
            tmp.sort(by: NewestFirst)
            for i in 0 ..< tmp.count {
                if !fc(0, tmp[i]!) { return }
            }
        }

        for level in 1 ..< config.kNumLevels {
            let num_files: Int = files_[level].count
            if num_files == 0 { continue }

            let index: Int = FindFile(vset_.icmp_, files_[level], internal_key)
            if index < num_files {
                let f: FileMetaData = files_[level][index]!
                if ucmp!.Compare(user_key, f.smallest.user_key()) < 0 {
                } else {
                    if !fc(level, f) { return }
                }
            }
        }
    }

    public func remove() {
        precondition(refs_ == 0, "refs_ = \(refs_) should be 0")
        let p: Version = prev_
        let n: Version = next_
        p.next_ = n
        n.prev_ = p

        next_ = nil
        prev_ = nil

        for level in 0 ..< config.kNumLevels {
            for i in 0 ..< files_[level].count {
                let f: FileMetaData = files_[level][i]!
                precondition(f.refs > 0, "f.refs = \(f.refs) should be greater than 0")
                f.refs -= 1
                if f.refs <= 0 { files_[level][i] = nil }
            }
        }
    }

    public struct GetStats {
        var seek_file: FileMetaData?
        var seek_file_level: Int = 0
    }

    public func AddIterators(_ options: ReadOptions, _ iters: inout Array<Iterator?>) {
        for i in 0 ..< files_[0].count {
            iters.append(vset_.table_cache_.NewIterator(options, files_[0][i]!.number, files_[0][i]!.file_size))
        }

        for level in 1 ..< config.kNumLevels {
            if !files_[level].isEmpty {
                iters.append(NewConcatenatingIterator(options, level))
            }
        }
    }

    public func Get(_ options: ReadOptions, _ k: LookupKey, _ val: BytesStorage, _ stats: inout GetStats) -> Status {
        stats.seek_file = nil
        stats.seek_file_level = -1

        struct State {
            var saver: Saver!
            var stats: GetStats!
            var options: ReadOptions = ReadOptions()
            var ikey: Slice = Slice()
            var last_file_read: FileMetaData?
            var last_file_read_level: Int = 0

            var vset: VersionSet!
            var s: Status = Status()
            var found: Bool = true

            static func Match(_ arg: State, _ level: Int, _ f: FileMetaData) -> Bool {
                var state: State = arg

                if state.stats.seek_file == nil && state.last_file_read != nil {
                    state.stats.seek_file = state.last_file_read
                    state.stats.seek_file_level = state.last_file_read_level
                }

                state.last_file_read = f
                state.last_file_read_level = level

                state.s = state.vset.table_cache_.Get(state.options, f.number, f.file_size, state.ikey, { s1, s2 in
                    SaveValue(state.saver, s1, s2) })
                if !state.s.ok() {
                    state.found = true
                    return false
                }
                switch state.saver.state {
                case .kNotFound:
                    return true
                case .kFound:
                    state.found = true
                    return false
                case .kDeleted:
                    return false
                case .kCorrupt:
                    state.s = Status.Corruption("corrupted key for ", state.saver.user_key.ToString())
                    state.found = true
                    return false
                }
            }
        }

        var state: State = State()
        state.found = false
        state.stats = stats
        state.last_file_read = nil
        state.last_file_read_level = -1

        state.options = options
        state.ikey = k.internal_key()
        state.vset = vset_

        state.saver.state = .kNotFound
        state.saver.ucmp = vset_.icmp_.user_comparator()!
        state.saver.user_key = k.user_key()
        state.saver.value = val

        ForEachOverlapping(state.saver.user_key, state.ikey, { level, f in
            State.Match(state, level, f) })

        return state.found ? state.s : Status.NotFound(Slice())
    }

    //  bool UpdateStats(const GetStats& stats);

    //  bool RecordReadSample(Slice key);

    public func Ref() { refs_ += 1 }

    public func UnRef() {
        precondition(self !== vset_.dummy_versions, "self = \(ObjectIdentifier(self)) should not be same with vset_.dummy_versions = \(ObjectIdentifier(vset_.dummy_versions))")
        precondition(refs_ >= 1, "refs_ = \(refs_) should be equal or greater than 1")
        refs_ -= 1
        if refs_ == 0 {
            remove()
        }
    }

    //  void GetOverlappingInputs(
//      int level,
//      const InternalKey* begin,  // nullptr means before all keys
//      const InternalKey* end,    // nullptr means after all keys
//      std::vector<FileMetaData*>* inputs);
//

    //  bool OverlapInLevel(int level, const Slice* smallest_user_key,
//                      const Slice* largest_user_key);

    //  int PickLevelForMemTableOutput(const Slice& smallest_user_key,
//                                 const Slice& largest_user_key);

    //  int NumFiles(int level) const { return files_[level].size(); }

    //  std::string DebugString() const;
}

public class VersionSet {
    public let options_: Options
    public let table_cache_: TableCache
    public let icmp_: InternalKeyComparator

    public var dummy_versions: Version!

    init(_ options: Options, _ table_cache: TableCache, _ cmp: InternalKeyComparator) {
        table_cache_ = table_cache
        icmp_ = cmp
        options_ = options
        dummy_versions = Version(self) // ??????
    }
}

fileprivate func TargetFileSize(_ options: Options) -> Int {
    return options.max_file_size
}

fileprivate func MaxGrandParentOverlapBytes(_ options: Options) -> Int64 {
    return Int64(TargetFileSize(options) * 10)
}

fileprivate func MaxFileSizeForLevel(_ options: Options, _ level: Int) -> UInt64 {
    return UInt64(TargetFileSize(options))
}

fileprivate func TotalFileSize(_ files: Array<FileMetaData>) -> Int64 {
    var sum: Int64 = 0
    for item in files {
        sum += Int64(item.file_size)
    }
    return sum
}

fileprivate class Compaction {
    private var level_: Int
    private var max_output_file_size_: UInt64
    private var input_version_: Version?
    private var edit_: VersionEdit = VersionEdit()
    private let inputs_: [2 of Array<FileMetaData>] = [[], []]
    private var grandparents_: Array<FileMetaData> = []
    private var grandparent_index_: Int = 0
    private var seen_key_: Bool = false
    private var overlapped_bytes_: Int64 = 0
    private var level_ptrs_: [7 of Int] = [0, 0, 0, 0, 0, 0, 0]

    init(_ options: Options, _ level: Int) {
        level_ = level
        max_output_file_size_ = MaxFileSizeForLevel(options, level)
    }

    public func level() -> Int { return level_ }

    public func edit() -> VersionEdit { return edit_ }

    public func num_input_files(_ which: Int) -> Int { return inputs_[which].count }

    public func input(_ which: Int, _ i: Int) -> FileMetaData? { return inputs_[which][i] }

    public func MaxOutputFileSize() -> UInt64 { return max_output_file_size_ }

    public func IsTrivialMove() -> Bool {
        let vset: VersionSet = input_version_!.vset_
        return num_input_files(0) == 1 && num_input_files(1) == 0 && (TotalFileSize(grandparents_) <= MaxGrandParentOverlapBytes(vset.options_))
    }

    public func AddInputDeletions(_ edit: VersionEdit) {
        for i in 0 ..< 2 {
            for it in inputs_[i] {
                edit.RemoveFile(level_ + i, it.number)
            }
        }
    }

    public func IsBaseLevelForKey(_ user_key: Slice) -> Bool {
        let user_cmp: (any Comparator)? = input_version_!.vset_.icmp_.user_comparator()
        for i in (level_ + 2) ..< config.kNumLevels {
            let files: Array<FileMetaData?> = input_version_!.files_[i]
            while level_ptrs_[i] < files.count {
                let f: FileMetaData = files[level_ptrs_[i]]!
                if user_cmp!.Compare(user_key, f.largest.user_key()) <= 0 {
                    if user_cmp!.Compare(user_key, f.smallest.user_key()) >= 0 { return false }
                    break
                }
                level_ptrs_[i] += 1
            }
        }
        return true
    }

    public func ShouldStopBefore(_ internal_key: Slice) -> Bool {
        let vset: VersionSet = input_version_!.vset_
        let icmp: InternalKeyComparator = vset.icmp_
        while (grandparent_index_ < grandparents_.count) && icmp.Compare(internal_key, grandparents_[grandparent_index_].largest.Encode()) > 0 {
            if seen_key_ {
                overlapped_bytes_ += Int64(grandparents_[grandparent_index_].file_size)
            }
            grandparent_index_ += 1
        }
        seen_key_ = true

        if overlapped_bytes_ > MaxGrandParentOverlapBytes(vset.options_) {
            overlapped_bytes_ = 0
            return true
        }
        return false
    }

    public func ReleaseInputs() {
        if input_version_ != nil {
            input_version_!.UnRef()
            input_version_ = nil
        }
    }
}
