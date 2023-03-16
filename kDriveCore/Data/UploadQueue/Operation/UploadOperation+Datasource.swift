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

extension UploadOperation {
    // MARK: Model

    /// Count of the chunks to upload, independent of chunk produced on local storage
    func chunkTasksToUploadCount() throws -> Int {
        var count: Int!
        try transactionWithFile { file in
            // Get the current uploading session
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            let filteredTasks = uploadingSessionTask.chunkTasks.filter(UploadingChunkTask.notDoneUploadingPredicate)
            count = filteredTasks.count
        }

        return count
    }

    /// Count of the uploaded chunks to upload, independent of chunk produced on local storage
    func chunkTasksUploadedCount() throws -> Int {
        var count: Int!
        try transactionWithFile { file in
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            let filteredTasks = uploadingSessionTask.chunkTasks.filter(UploadingChunkTask.doneUploadingPredicate)
            count = filteredTasks.count
        }
        return count
    }

    /// How many chunk requests are active at the moment
    func chunkTasksUploadingCount() throws -> Int {
        var count: Int!
        try transactionWithFile { file in
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            let filteredTasks = uploadingSessionTask.chunkTasks.filter(UploadingChunkTask.scheduledPredicate)
            count = filteredTasks.count
        }
        return count
    }

    /// Count of the chunks to upload, independent of chunk produced on local storage
    func chunkTasksTotalCount() throws -> Int {
        var count: Int!
        try transactionWithFile { file in
            // Get the current uploading session
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            count = uploadingSessionTask.chunkTasks.count
        }
        return count
    }

    // MARK: Misc

    func getDriveFileManager() throws -> DriveFileManager {
        guard let driveFileManager = accountManager.getDriveFileManager(for: accountManager.currentDriveId,
                                                                        userId: accountManager.currentUserId) else {
            UploadOperationLog("getDriveFileManager failed \(uploadFileId)", level: .error)
            throw DriveError.localError
        }

        return driveFileManager
    }
}
