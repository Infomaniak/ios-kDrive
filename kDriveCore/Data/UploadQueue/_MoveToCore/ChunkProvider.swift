/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

/// Something that builds chunks and provide them with an iterator.
public protocol ChunkProvidable: IteratorProtocol {
    init?(fileURL: URL, ranges: [DataRange])
}

/// Something that can chunk a file part by part, in memory, given specified ranges.
///
/// Memory considerations: Max memory use ~= sizeOf(one chunk). So between 1Mb to 50Mb
/// Thread safety: Not thread safe
///
@available(iOS 13.4, *)
public final class ChunkProvider: ChunkProvidable {
    public typealias Element = Data
    
    let fileHandle: FileHandlable
    
    var ranges: [DataRange]

    deinit {
        do {
            // For the sake of consistency
            try fileHandle.close()
        } catch {}
    }
    
    public init?(fileURL: URL, ranges: [DataRange]) {
        self.ranges = ranges
        
        do {
            self.fileHandle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            return nil
        }
    }
    
    /// Internal testing method
    init(mockedHandlable: FileHandlable, ranges: [DataRange]) {
        self.ranges = ranges
        self.fileHandle = mockedHandlable
    }
    
    /// Will provide chunks one by one, using the IteratorProtocol
    /// Starting by the first range availlable.
    public func next() -> Data? {
        guard ranges.isEmpty == false else {
            return nil
        }
        
        let range = ranges.removeFirst()
        
        do {
            let chunk = try readChunk(range: range)
            return chunk
        } catch {
            return nil
        }
    }
    
    // MARK: Internal
    
    func readChunk(range: DataRange) throws -> Data? {
        let offset = range.lowerBound
        try fileHandle.seek(toOffset: offset)
        
//        #if DEBUG
//        let fileHandleOffset = try fileHandle.offset()
//        print(fileHandle, "\n~> Range Offset: \(offset)")
//        assert(fileHandleOffset == offset)
//        #endif
        
        let byteCount = Int(range.upperBound - range.lowerBound) + 1
        let chunk = try fileHandle.read(upToCount: byteCount)
        return chunk
    }
}

/// Print the FileHandle shows the current offset
extension FileHandle {
    override open var description: String {
        let superDescription = super.description
        
        let offsetString: String
        do {
            let offset = try self.offset()
            offsetString = "\(offset)"
        } catch {
            offsetString = "\(error)"
        }
        
        let buffer = """
        <\(superDescription)>
        <offset:\(offsetString)>
        """
        
        return buffer
    }
}

/// Protocol conformance
extension FileHandle: FileHandlable {}

/// Something that matches most of the FileHandle specification
protocol FileHandlable {
    var availableData: Data { get }
    
    var description: String { get }
    
    func seek(toOffset offset: UInt64) throws
    
    func truncate(atOffset offset: UInt64) throws
    
    func synchronize() throws
    
    func close() throws
    
    func readToEnd() throws -> Data?
    
    func read(upToCount count: Int) throws -> Data?
    
    func offset() throws -> UInt64
    
    func seekToEnd() throws -> UInt64
}

/// Mocking part of the `FileHandle` API
///
/// Inherits from NSObject for free description implementation
final class MCKFileHandlable: NSObject, FileHandlable {
    
    var availableData: Data = Data()
    
    // MARK: - seek(toOffset:)
    var seekToOffsetCalled: Bool { seekToOffsetCallCount > 0 }
    var seekToOffsetCallCount: Int = 0
    var seekToOffsetClosure: ((UInt64) -> Void)?
    var seekToOffsetError: Error?
    func seek(toOffset offset: UInt64) throws {
        seekToOffsetCallCount += 1
        if let seekToOffsetError {
            throw seekToOffsetError
        }
        else if let seekToOffsetClosure {
            seekToOffsetClosure(offset)
        }
    }
    
    // MARK: - truncate(atOffset:)
    var truncateCalled: Bool { truncateCallCount > 0 }
    var truncateCallCount: Int = 0
    var truncateClosure: ((UInt64) -> Void)?
    func truncate(atOffset offset: UInt64) throws {
        truncateCallCount += 1
        if let truncateClosure {
            truncateClosure(offset)
        }
    }
    
    // MARK: - synchronize
    
    var synchronizeCalled: Bool { synchronizeCallCount > 0 }
    var synchronizeCallCount: Int = 0
    var synchronizeClosure: (() -> Void)?
    func synchronize() throws {
        synchronizeCallCount += 1
        if let synchronizeClosure {
            synchronizeClosure()
        }
    }
    
    // MARK: - close
    
    var closeCalled: Bool { closeCallCount > 0 }
    var closeCallCount: Int = 0
    var closeClosure: (() -> Void)?
    func close() throws {
        closeCallCount += 1
        if let closeClosure {
            closeClosure()
        }
    }
    
    // MARK: - readToEnd
    
    var readToEndCalled: Bool { readToEndCallCount > 0 }
    var readToEndCallCount: Int = 0
    var readToEndClosure: (() -> Data)?
    func readToEnd() -> Data? {
        readToEndCallCount += 1
        if let readToEndClosure {
            return readToEndClosure()
        } else {
            return nil
        }
    }
    
    // MARK: - read(upToCount:)
    
    var readUpToCountCalled: Bool { readUpToCountCallCount > 0 }
    var readUpToCountCallCount: Int = 0
    var readUpToCountClosure: ((Int) -> Data)?
    var readUpToCountError: Error?
    func read(upToCount count: Int) throws -> Data? {
        readUpToCountCallCount += 1
        if let readUpToCountError {
            throw readUpToCountError
        }
        else if let readUpToCountClosure {
            return readUpToCountClosure(count)
        } else {
            return nil
        }
    }
    
    // MARK: - offset
    
    var offsetCalled: Bool { offsetCallCount > 0 }
    var offsetCallCount: Int = 0
    var offsetClosure: (() -> UInt64)?
    func offset() -> UInt64 {
        offsetCallCount += 1
        if let offsetClosure {
            return offsetClosure()
        } else {
            return UInt64(NSNotFound)
        }
    }
    
    // MARK: - seekToEnd
    
    var seekToEndCalled: Bool { seekToEndCallCount > 0 }
    var seekToEndCallCount: Int = 0
    var seekToEndClosure: (() -> UInt64)?
    func seekToEnd() -> UInt64 {
        seekToEndCallCount += 1
        if let seekToEndClosure {
            return seekToEndClosure()
        } else {
            return UInt64(NSNotFound)
        }
    }
    
}
