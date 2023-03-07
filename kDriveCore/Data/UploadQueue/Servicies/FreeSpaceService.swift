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

/// Something to monitor storage space
public struct FreeSpaceService {
    public init() {
        // Required
    }

    public enum StorageIssues: Error {
        /// Not enough space for specified operation
        case notEnoughSpace
        /// Unable to estimate free space
        case unableToEstimate
        /// An underlaying error has occurred
        case unavailable(wrapping: Error)
    }

    private static let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

    ///  The minimum available space required to start uploading with chunks
    ///
    /// ≈ 4chunks with a max chunk size of 50 meg + 20% = 220MiB
    private static let minimalSpaceRequiredForChunkUpload = 220 * 1024 * 1024

    public func checkEnoughAvailableSpaceForChunkUpload() throws {
        let freeSpaceInTemporaryDirectory: Int64
        do {
            freeSpaceInTemporaryDirectory = try freeSpace(url: Self.temporaryDirectoryURL)
        } catch {
            UploadOperationLog("unable to read available space \(error)", level: .error)
            return
        }

        // Throw only if certain of not enough space
        guard freeSpaceInTemporaryDirectory > Self.minimalSpaceRequiredForChunkUpload else {
            throw StorageIssues.notEnoughSpace
        }
    }

    // MARK: - private

    private func freeSpace(url: URL) throws -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
                // volumeAvailableCapacityForImportantUsage not available
                throw StorageIssues.unableToEstimate
            }

            return capacity
        } catch {
            throw StorageIssues.unavailable(wrapping: error)
        }
    }
}
