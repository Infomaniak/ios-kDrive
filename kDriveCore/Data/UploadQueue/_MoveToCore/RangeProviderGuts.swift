/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

/// The internal methods of RangeProviderGuts, made testable
///
// TODO: Remove public (protocol and implementation) as soon as moved to Core
public protocol RangeProviderGutsable {
    /// Build ranges for a file
    /// - Parameters:
    ///   - fileSize: the total file size, in **Bytes**
    ///   - totalChunksCount: the total number of chunks that should be used
    ///   - chunkSize: the size of a chunk that should be used
    /// - Returns: a collection of contiguous (so ordered) ranges.
    func buildRanges(fileSize: UInt64, totalChunksCount: UInt64, chunkSize: UInt64) -> [DataRange]
    
    /// Get the size of a file, in **Bytes**
    /// - Returns: the file size at the moment of execution
    func readFileByteSize() throws -> UInt64
    
    /// Mimmic the Android logic and returns what is prefered by the API for a specific file size
    /// - Parameter fileSize: the input file size, in **Bytes**
    /// - Returns: The _prefered_ size of one chunk
    func preferedChunkSize(for fileSize: UInt64) -> UInt64
}

/// Subdivided **RangeProvider**, so it is easier to test
public struct RangeProviderGuts: RangeProviderGutsable {
    /// The URL of the local file to scan
    public let fileURL: URL
    
    public func buildRanges(fileSize: UInt64, totalChunksCount: UInt64, chunkSize: UInt64) -> [DataRange] {
        guard fileSize > 0,
              totalChunksCount > 0,
              chunkSize > 0 else {
            return []
        }
        
        let totalChunckedSize = totalChunksCount * chunkSize
        // sanity file size check
        guard totalChunckedSize <= fileSize else {
            return []
        }
        
        // The high bound for a 0 indexed list of bytes
        let chunkBound = chunkSize - 1
        
        var ranges: [DataRange] = []
        for index in 0...totalChunksCount - 1 {
            let startOffset = index * chunkBound + index
            let endOffset = startOffset + chunkBound
            let range: DataRange = startOffset...endOffset
            
            ranges.append(range)
        }
        
        // Add the remainder in a last chuck
        let lastChunkSize = fileSize - totalChunckedSize
        if lastChunkSize != 0 {
            let startOffset = totalChunksCount * chunkSize
            assert((startOffset + lastChunkSize) == fileSize, "sanity, this should match")
            
            let EoFoffset = fileSize - 1
            let range: DataRange = startOffset...EoFoffset
            
            ranges.append(range)
        }
        
        return ranges
    }
    
    public func readFileByteSize() throws -> UInt64 {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileSize = fileAttributes[.size] as? UInt64 else {
            throw RangeProvider.ErrorDomain.UnableToReadFileAttributes
        }
        
        return fileSize
    }
    
    public func preferedChunkSize(for fileSize: UInt64) -> UInt64 {
        let potentialChunkSize = fileSize / RangeProvider.APIConsts.optimalChunkCount
        
        let chunkSize: UInt64
        switch potentialChunkSize {
        case 0 ..< RangeProvider.APIConsts.chunkMinSize:
            chunkSize = RangeProvider.APIConsts.chunkMinSize
        
        case RangeProvider.APIConsts.chunkMinSize...RangeProvider.APIConsts.chunkMaxSize:
            chunkSize = potentialChunkSize
        
        /// Strictly higher than `APIConsts.chunkMaxSize`
        default:
            chunkSize = RangeProvider.APIConsts.chunkMaxSize
        }
        
        return chunkSize
    }
}
