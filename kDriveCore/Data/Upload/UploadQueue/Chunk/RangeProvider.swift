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

    /// Return the file size in bytes at the moment of calling.
    var fileSize: UInt64 { get throws }
}

public struct RangeProvider: RangeProvidable {
    /// Encapsulating API parameters used to compute ranges
    public enum APIConstants {
        static let chunkMinSize: UInt64 = 1 * 1024 * 1024
        static let chunkMaxSizeClient: UInt64 = 50 * 1024 * 1024
        static let chunkMaxSizeServer: UInt64 = 1 * 1024 * 1024 * 1024
        static let optimalChunkCount: UInt64 = 200
        static let maxTotalChunks: UInt64 = 10000
        static let minTotalChunks: UInt64 = 1

        /// the limit supported by the app
        static let fileMaxSizeClient = APIConstants.maxTotalChunks * APIConstants.chunkMaxSizeClient

        /// the limit supported by the server
        static let fileMaxSizeServer = APIConstants.maxTotalChunks * APIConstants.chunkMaxSizeServer
    }

    enum ErrorDomain: Error {
        /// Unable to read file system metadata
        case UnableToReadFileAttributes

        /// file is over the supported size
        case FileTooLarge

        /// We ask for chunks that do not make sense
        case ChunkedSizeLargerThanSourceFile

        /// At least one chunk is expected
        case IncorrectTotalChunksCount

        /// A non zero size is expected
        case IncorrectChunkSize
    }

    /// The internal methods split into another type, make testing easier
    var guts: RangeProviderGutsable

    public init(fileURL: URL) {
        guts = RangeProviderGuts(fileURL: fileURL)
    }

    public var fileSize: UInt64 {
        get throws {
            let size = try guts.readFileByteSize()
            return size
        }
    }

    public var allRanges: [DataRange] {
        get throws {
            let size = try fileSize

            // Check for files too large to be processed by mobile app or the server
            guard size < APIConstants.fileMaxSizeClient,
                  size < APIConstants.fileMaxSizeServer else {
                // TODO: notify Sentry
                throw ErrorDomain.FileTooLarge
            }

            let preferredChunkSize = guts.preferredChunkSize(for: size)

            // Make sure an empty file resolves to one chunk
            let totalChunksCount = max(size / max(preferredChunkSize, 1), 1)

            let ranges = try guts.buildRanges(fileSize: size,
                                              totalChunksCount: totalChunksCount,
                                              chunkSize: preferredChunkSize)

            return ranges
        }
    }
}
