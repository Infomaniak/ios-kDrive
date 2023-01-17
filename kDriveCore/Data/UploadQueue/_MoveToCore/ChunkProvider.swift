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
    
    let fileHandle: FileHandle
    
    var ranges: [DataRange]
    
    public init?(fileURL: URL, ranges: [DataRange]) {
        self.ranges = ranges.reversed()
        
        do {
            self.fileHandle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            return nil
        }
    }
    
    /// Will provide chunks one by one, using the IteratorProtocol
    /// Starting by the first range availlable.
    public func next() -> Data? {
        guard let range = ranges.popLast() else {
            return nil
        }
        
        do {
            try fileHandle.seek(toOffset: range.lowerBound)
            let chunk = try fileHandle.read(upToCount: Int(range.upperBound))
            
            return chunk
        } catch {
            // TODO: throw error, or fail silently ?
            return nil
        }
    }
    
}


/*
 
 let rangeProvider: RangeProvider
 rangeProvider = RangeProvider(fileURL: fileURL)
 rangeProvider.allRanges
 
 */
