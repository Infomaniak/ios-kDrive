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
import InfomaniakCore

extension UploadOperation: ExpiringActivityDelegate {
    public func backgroundActivityExpiring() {
        Log.uploadOperation("backgroundActivityExpiring ufid:\(uploadFileId)")
        SentryDebug.uploadOperationBackgroundExpiringBreadcrumb(uploadFileId)

        // Take a snapshot of the running tasks
        var rescheduleIterator = uploadTasks.makeIterator()
        var cancelIterator = uploadTasks.makeIterator()

        // Schedule a db transaction to set .taskRescheduled error on chunks
        enqueueCatching {
            try self.transactionWithFile { file in
                file.error = .taskRescheduled
                Log
                    .uploadOperation(
                        "Rescheduling didReschedule .taskRescheduled uploadTasks:\(self.uploadTasks) ufid:\(self.uploadFileId)"
                    )

                // Make sure the main app can continue the upload next retry.
                file.ownedByFileProvider = false

                // Mark all chunks in base with a .taskRescheduled error
                var iterator = self.uploadTasks.makeIterator()
                try self.cleanUploadSessionUploadTaskNotUploading(iterator: &iterator)

                while let (taskIdentifier, _) = rescheduleIterator.next() {
                    // Match chunk in base and set error to .taskRescheduled
                    let chunkTasksToClean = file.uploadingSession?.chunkTasks.filter(NSPredicate(
                        format: "taskIdentifier = %@",
                        taskIdentifier
                    )).first

                    if let chunkTasksToClean {
                        chunkTasksToClean.error = .taskRescheduled
                    } else {
                        Log.uploadOperation(
                            "Unable to match chunk to reschedule for identifier:\(taskIdentifier) ufid:\(self.uploadFileId)",
                            level: .error
                        )
                    }
                }

                // Sentry
                let metadata = ["File id": self.uploadFileId,
                                "File size": file.size,
                                "File type": file.type.rawValue]
                SentryDebug.uploadOperationRescheduledBreadcrumb(self.uploadFileId, metadata)
            }

            self.uploadNotifiable.sendPausedNotificationIfNeeded()

            // each and all operations should be given the chance to call backgroundActivityExpiring
            self.end()

            Log.uploadOperation("Rescheduling end ufid:\(self.uploadFileId)")
        }

        // Cancel all chunk network requests ASAP
        while let (_, sessionUploadTask) = cancelIterator.next() {
            sessionUploadTask.cancel()
        }

        Log.uploadOperation("exit reschedule ufid:\(uploadFileId)")
    }
}
