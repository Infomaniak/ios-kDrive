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

/// A range of Bytes on a `Data` buffer
///   - start: start byte index, first index at 0 by convention.
///   - end: end byte index, last index at fileSize -1 by convention.
public typealias DataRange = ClosedRange<UInt64>

/// Something that can provide a sequence of ranges where the file should be split if necessary.
public protocol RangeProvidable {
    /// Computes and return all the contiguous ranges for a file at the moment of calling.
    ///
    /// Result may change over time if file is modified in between calls.
    /// Throws if file too large or too small, also if file system issue.
    /// Minimum size support is one byte (low bound == high bound)
    var allRanges: [DataRange] { get throws }
}

public struct RangeProvider: RangeProvidable {
    /// Encapsulating API parameters used to compute ranges
    public enum APIConsts {
        static let chunkMinSize: UInt64 = 1 * 1024 * 1024
        static let chunkMaxSize: UInt64 = 50 * 1024 * 1024
        static let optimalChunkCount: UInt64 = 200
        static let maxTotalChunks: UInt64 = 10_000
        static let minTotalChunks: UInt64 = 1
        
        /// On kDrive a file cannot exceed 50GiB, not linked to chunk API
        static let fileMaxSize: UInt64 = 50 * 1024 * 1024 * 1024
    }
    
    enum ErrorDomain: Error {
        /// Unable to read file system metadata
        case UnableToReadFileAttributes
        
        /// file is under the suported size, may be empty
        case FileTooSmall
        
        /// file is over the suported size
        case FileTooLarge
    }
    
    /// The internal methods split into another type, make testing easier
    var guts: RangeProviderGutsable
    
    public init(fileURL: URL) {
        self.guts = RangeProviderGuts(fileURL: fileURL)
    }
    
    public var allRanges: [DataRange] {
        get throws {
            let fileSize = try guts.readFileByteSize()
            
            // Small (including empty) files are not suited for chunk upload
            guard fileSize > APIConsts.chunkMinSize else {
                throw ErrorDomain.FileTooSmall
            }
            
            // Check for files too large to be processed
            guard fileSize < APIConsts.fileMaxSize else {
                // TODO: notify Sentry
                throw ErrorDomain.FileTooLarge
            }
            
            let preferedChunkSize = guts.preferedChunkSize(for: fileSize)
            
            // Check the file is larger than one chunk
            guard fileSize > preferedChunkSize else {
                throw ErrorDomain.FileTooSmall
            }
            let totalChunksCount = fileSize / preferedChunkSize
            
            let ranges = guts.buildRanges(fileSize: fileSize, totalChunksCount: totalChunksCount, chunkSize: preferedChunkSize)
            
            return ranges
        }
    }
}

/// A publicly availlable mock of RangeProvidable
public final class MCKRangeProvidable: RangeProvidable {
    
    var allRangesCalled: Bool { allRangesCallCount > 0 }
    var allRangesCallCount: Int = 0
    var allRangesThrows: Error?
    var allRangesClosure: (()->[DataRange])?
    public var allRanges: [DataRange] {
        get throws {
            allRangesCallCount += 1
            if let allRangesThrows {
                throw allRangesThrows
            }
            else if let allRangesClosure {
                return allRangesClosure()
            }
            else {
                return []
            }
        }
     }
}


