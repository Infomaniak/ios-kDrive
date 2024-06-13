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
import InfomaniakDI
import RealmSwift

/// Something to monitor storage space
public struct FreeSpaceService {
    @LazyInjectService var uploadQueue: UploadQueue

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

    private static let temporaryDirectoryURL = DriveFileManager.constants.tmpDirectoryURL

    private static let importDirectoryURL = DriveFileManager.constants.importDirectoryURL

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

    /// Run cache consistency checks
    public func auditCache() {
        cleanOrphanFiles()
        cleanCacheIfAlmostFull()
    }

    /// Check for orphan files in the import folder, clean if file is not tracked in DB.
    private func cleanOrphanFiles() {
        let fileManager = FileManager.default
        do {
            // Read content of import folder
            let cachedFiles = try fileManager.contentsOfDirectory(atPath: Self.importDirectoryURL.path)
            Log.uploadOperation("found \(cachedFiles.count) in the import directory")

            // Get uploading in progress tracked in DB
            let uploadingFiles = uploadQueue.getAllUploadingFilesFrozen()

            // Match files on SSD against DB, delete if not matched.
            let filesToClean = cachedFiles.filter { cachedFileName in
                let cachedFileIsUploading = uploadingFiles.contains { uploadFile in
                    guard let uploadFileUrl = uploadFile.url else {
                        return false
                    }
                    return uploadFileUrl.hasSuffix(cachedFileName)
                }

                return !cachedFileIsUploading
            }

            Log.uploadOperation("cleanning \(filesToClean.count) files in import folder", level: .info)
            for fileToClean in filesToClean {
                let fileToCleanURL = Self.importDirectoryURL.appendingPathComponent(fileToClean)
                try? fileManager.removeItem(at: fileToCleanURL)
            }
        } catch {
            Log.uploadOperation("Unexpected error working with import folder:\(error)", level: .error)
        }
    }

    /// On devices with low free space, we clear the temporaryDirectory on exit
    private func cleanCacheIfAlmostFull() {
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

        // Clean temp files we are absolutely sure will not end up with a data loss.
        let temporaryDirectory = Self.temporaryDirectoryURL
        try? FileManager.default.removeItem(at: temporaryDirectory)
        // Recreate directory to avoid any issue
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
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
