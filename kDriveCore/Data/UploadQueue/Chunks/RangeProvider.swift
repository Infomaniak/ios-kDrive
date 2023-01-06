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
///   - start: start byte index
///   - end: end byte index
public typealias DataRange = ClosedRange<UInt64>

/// Something that can provide a view on where the files should be split if necessary
///
/// Throws if file too large or too small. Also if file system issue
public protocol RangeProvidable {
    
    var fileURL: URL { get }
    
    var allRanges: [DataRange] { get throws }
    
}

public struct RangeProvider: RangeProvidable {
    
    enum APIConsts {
        static let chunkMinSize: UInt64 = 1 * 1024 * 1024
        static let chunkMaxSize: UInt64 = 50 * 1024 * 1024
        static let optimalChunkCount: UInt64 = 200
        static let maxTotalChunks: UInt64 = 10_000
    }
    
    public let fileURL: URL
    
    enum ErrorDomain: Error {
        /// Unable to read file system metadata
        case UnableToReadFileAttributes
        
        /// file is under the suported size, may be empty
        case FileTooSmall
        
        /// file is over the suported size
        case FileTooLarge
    }
    
    public var allRanges: [DataRange] {
        get throws {
            let fileSize = try readFileSize()
            
            // Small (including empty) files are not suited for chunk upload
            guard fileSize > APIConsts.chunkMinSize else {
                throw ErrorDomain.FileTooSmall
            }
            
            // Check for files too large to be processed
            let totalChunksCount = fileSize / APIConsts.chunkMaxSize
            guard totalChunksCount < APIConsts.maxTotalChunks else {
                // TODO: notify Sentry
                throw ErrorDomain.FileTooLarge
            }
            
            let preferedChunkSize = preferedChunkSize(for: fileSize)
            let ranges = buildRanges(fileSize: fileSize, totalChunksCount: totalChunksCount, chunkSize: preferedChunkSize)
            
            return ranges
        }
    }
    
    func buildRanges(fileSize: UInt64, totalChunksCount: UInt64, chunkSize: UInt64) -> [DataRange] {
        let chunckedSize = totalChunksCount*chunkSize
        assert(chunckedSize <= fileSize, "sanity file size check")
        
        var ranges: [DataRange] = []
        for index in 0...totalChunksCount {
            let startOffset = index*chunckedSize
            let endOffset = startOffset+chunckedSize
            let range: DataRange = startOffset...endOffset
            
            ranges.append(range)
        }
        
        // Add the remainder in a last chuck
        let lastChunkSize = fileSize - chunckedSize
        if lastChunkSize > 0 {
            let startOffset = totalChunksCount*chunkSize
            assert((startOffset+lastChunkSize)==fileSize, "sanity, this should match")
            
            let endOffset = fileSize
            let range: DataRange = startOffset...endOffset
            
            ranges.append(range)
        }
        
        return ranges
    }
    
    /// we read the atributes to get the total file size
    func readFileSize() throws -> UInt64 {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = fileAttributes[.size] as? UInt64 else {
            throw ErrorDomain.UnableToReadFileAttributes
        }
        
        return fileSize
    }
    
    /// Matching Android implementation of the prefered chunk size logic
    ///
    /// TODO: review with backend guys maybe ?
    func preferedChunkSize(for fileSize: UInt64) -> UInt64 {
        let potentialChunkSize = fileSize / APIConsts.optimalChunkCount
        
        assert(potentialChunkSize<=APIConsts.chunkMaxSize, "should be smaller than max size")
        assert(potentialChunkSize>=APIConsts.chunkMinSize, "should be smaller than min size")
        
        let chunkSize: UInt64
        switch potentialChunkSize {
        case 0..<APIConsts.chunkMinSize:
            chunkSize = APIConsts.chunkMinSize
        
        case APIConsts.chunkMinSize...APIConsts.chunkMaxSize:
            chunkSize = potentialChunkSize
        
        /// Strictly higher than `APIConsts.chunkMaxSize`
        default:
            chunkSize = APIConsts.chunkMaxSize
        }
        
        return chunkSize
    }
    
}
