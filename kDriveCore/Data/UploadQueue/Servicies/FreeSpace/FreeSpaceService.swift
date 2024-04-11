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
    /// ≈ n chunks with a max chunk size of 50 meg + 20%. 220MiB for 4 cores.
    private var minimalSpaceRequiredForChunkUpload: Int64 {
        let parallelism = max(4, ProcessInfo.processInfo.activeProcessorCount)
        var requiredSpace = Int64(parallelism * 50 * 1024 * 1024)
        requiredSpace += requiredSpace * 100 / 20
        let mebibytes = String(format: "%.2f", BinaryDisplaySize.bytes(UInt64(requiredSpace)).toMebibytes)
        Log.uploadOperation("minimalSpaceRequiredForChunkUpload is \(mebibytes)MiB")
        return requiredSpace
    }

    public func checkEnoughAvailableSpaceForChunkUpload() throws {
        let freeSpaceInTemporaryDirectory: Int64
        do {
            freeSpaceInTemporaryDirectory = try freeSpace(url: Self.temporaryDirectoryURL)
        } catch {
            Log.uploadOperation("unable to read available space \(error)", level: .error)
            return
        }

        // Throw if not enough space
        guard freeSpaceInTemporaryDirectory > minimalSpaceRequiredForChunkUpload else {
            throw StorageIssues.notEnoughSpace
        }
    }

    /// On devices with low free space, we clear the temporaryDirectory on exit
    public func cleanCacheIfAlmostFull() {
        let freeSpaceInTemporaryDirectory: Int64
        do {
            freeSpaceInTemporaryDirectory = try freeSpace(url: Self.temporaryDirectoryURL)
        } catch {
            Log.uploadOperation("unable to read available space \(error)", level: .error)
            return
        }

        // Only clean if reaching the minimum space required for upload
        guard freeSpaceInTemporaryDirectory < minimalSpaceRequiredForChunkUpload * 2 else {
            return
        }

        Log.uploadOperation("Almost not enough space for chunk upload, clearing temporary files")
        let cleanActions = CleanSpaceActions()

        // Clean temp files we are absolutely sure will not end up with a data loss.
        let temporaryDirectory = FileManager.default.temporaryDirectory.path
        let size = cleanActions.getFileSize(at: temporaryDirectory)
        let temporaryStorageCache = StorageFile(path: temporaryDirectory, size: size)
        cleanActions.delete(file: temporaryStorageCache)
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
