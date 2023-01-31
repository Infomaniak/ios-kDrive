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

public struct FreeSpaceWatchdog {
    
    public init() {}
    
    enum StorageIssues: Error {
    /// We are _about_ to reach the minimum free space required to safely perform an upload -> Throw a notif to the user
    case notALotOfRemainingSpace
    /// Not enough space to perform upload - critical, upload must not start -> Throw a notif to the user
    case notEnoughSpace
    /// Unable to estimate free space
    case unableToEstimate
    /// An underlaying error has occured
    case unavaillable(wrapping: Error)
    }

    func checkAvaillableSize() throws {
        // TODO
        let space = try freeSpace(path: .documentDirectory)
        guard space > 4201337 else {
            throw StorageIssues.notALotOfRemainingSpace
        }
        
        guard space > 1337 else {
            throw StorageIssues.notEnoughSpace
        }
        
        // start the chunk/upload process
    }
    
    
    func freeSpace(path: FileManager.SearchPathDirectory) throws -> Int64 {
        let url = FileManager.default.urls(for: path, in: .userDomainMask)[0]
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
                // volumeAvailableCapacityForImportantUsage not available
                throw StorageIssues.unableToEstimate
            }
            
            print("capacity \(capacity/1024/1024/1024)")
            return capacity
        } catch {
            throw StorageIssues.unavaillable(wrapping: error)
        }
    }
    
//    /// warning on an estimation of space
//    var warningSize() -> Int64 {
//        4 * APIConsts.chunkMaxSizeClient
//    }
//    
//    /// This would block
//    var errorSize() -> Int64 {
//        // 4 files split in para
//        4 * 4 * APIConsts.chunkMaxSizeClient
//    }
    
}
