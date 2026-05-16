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

        // Snapshot the in-flight chunk task identifier (if any) so we can mark it
        // as rescheduled in DB before cancelling the underlying network request.
        let inflightTaskIdentifier: String?
        if let task = currentUploadTask {
            inflightTaskIdentifier = urlSession.identifier(for: task)
        } else {
            inflightTaskIdentifier = nil
        }

        // Schedule a db transaction to flag the upload and chunk as rescheduled.
        enqueueCatching {
            try self.transactionWithFile { file in
                file.error = .taskRescheduled
                Log.uploadOperation("Rescheduling .taskRescheduled ufid:\(self.uploadFileId)")

                // Make sure the main app can continue the upload next retry.
                file.ownedByFileProvider = false

                if let inflightTaskIdentifier {
                    let chunkTaskToReschedule = file.uploadingSession?.chunkTasks.filter(NSPredicate(
                        format: "taskIdentifier = %@",
                        inflightTaskIdentifier
                    )).first

                    if let chunkTaskToReschedule, chunkTaskToReschedule.chunk == nil {
                        chunkTaskToReschedule.error = .taskRescheduled
                    } else if chunkTaskToReschedule == nil {
                        Log.uploadOperation(
                            "Unable to match chunk to reschedule for identifier:\(inflightTaskIdentifier) ufid:\(self.uploadFileId)",
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

        // Cancel the in-flight chunk network request ASAP
        currentUploadTask?.cancel()

        Log.uploadOperation("exit reschedule ufid:\(uploadFileId)")
    }
}
