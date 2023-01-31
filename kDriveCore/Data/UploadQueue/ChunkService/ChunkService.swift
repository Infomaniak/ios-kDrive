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

enum ChunkTaskResult {
    case success(file: URL)
    case error(wrapped: Error, file: URL)
}

protocol ChunkTaskResultable {
    
    func didFinish(state: ChunkTaskResult)
    
}

// MARK: - ChunkService

/// Something that oversees the splitting of a file or a collection of files.
public final class ChunkService {
    
    public init() { }
    
    public func enqueueFiles(_ urls:[URL]) {
        
    }
}

struct ChunkTask {

    let fileURL :URL
    let rangeProvider: RangeProvider
    let sessionData: [AnyHashable: Any]
    
    enum ErrorDomain: Error {
        case unableToAcquireHandle
    }
    
    init?(fileURL: URL, sessionData:[AnyHashable: Any]) {
        self.fileURL = fileURL
        self.sessionData = sessionData
        self.rangeProvider = RangeProvider(fileURL: fileURL)
    }

    func work() {
        do {
            let ranges = try self.rangeProvider.allRanges
            guard let chunkProvider = ChunkProvider(fileURL: fileURL, ranges: ranges) else {
                throw ErrorDomain.unableToAcquireHandle
            }
            
            var index = 0
            while let chunk = chunkProvider.next() {
                do {
                    try saveToSpecialStorage(buffer: chunk, index: index, sessionData: self.sessionData)
                } catch {
                    handleError(error, chunk: chunk)
                }
                
                index += 1
            }
        }
        catch {
            /* file too large, skip*/
            print("TODO handle error \(error)")
        }
    }
    
    func saveToSpecialStorage(buffer: Data, index: Int, sessionData: [AnyHashable: Any]) throws {
        
    }
    
    func handleError(_ error: Error, chunk: Data) {
        // What to do when fail, space not enough maybe ?
    }
}
