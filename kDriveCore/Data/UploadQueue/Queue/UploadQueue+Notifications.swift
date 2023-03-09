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
import UIKit

public protocol UploadNotifiable {
    /// Notify the user that we have not enough storage to start an upload.
    func sendNotEnoughSpaceForUpload(filename: String)

    /// Send a local notification that the system has paused the upload.
    func sendPausedNotificationIfNeeded()

    /// Send a local notification that n files were uploaded
    func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult)
}

extension UploadQueue: UploadNotifiable {
    public func sendNotEnoughSpaceForUpload(filename: String) {
        UploadQueueLog("sendNotEnoughSpaceForUpload")
        self.serialQueue.async { [unowned self] in
            self.notificationHelper.sendNotEnoughSpaceForUpload(filename: filename)
        }
    }

    public func sendPausedNotificationIfNeeded() {
        UploadQueueLog("sendPausedNotificationIfNeeded")
        self.serialQueue.async { [unowned self] in
            if !self.pausedNotificationSent {
                self.notificationHelper.sendPausedUploadQueueNotification()
                self.pausedNotificationSent = true
            }
        }
    }

    public func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult) {
        UploadQueueLog("sendFileUploadedNotificationIfNeeded")
        self.serialQueue.async { [unowned self] in
            guard let uploadFile = result.uploadFile,
                  uploadFile.error != .taskRescheduled,
                  uploadFile.error != .taskCancelled else {
                return
            }

            self.fileUploadedCount += (uploadFile.error == nil ? 1 : 0)
            if let error = uploadFile.error {
                let uploadedFileName = result.driveFile?.name ?? uploadFile.name
                self.notificationHelper.sendUploadError(filename: uploadedFileName,
                                                        parentId: uploadFile.parentDirectoryId,
                                                        error: error)
                if self.operationQueue.operationCount == 0 {
                    self.fileUploadedCount = 0
                }
            } else if self.operationQueue.operationCount == 0 {
                // In some cases fileUploadedCount can be == 1 but the result.uploadFile isn't necessary the last file *successfully* uploaded
                if self.fileUploadedCount == 1 && uploadFile.error == nil {
                    let uploadedFileName = result.driveFile?.name ?? uploadFile.name
                    self.notificationHelper.sendUploadDoneNotification(filename: uploadedFileName,
                                                                       parentId: uploadFile.parentDirectoryId)
                } else if self.fileUploadedCount > 0 {
                    self.notificationHelper.sendUploadDoneNotification(uploadCount: self.fileUploadedCount,
                                                                       parentId: uploadFile.parentDirectoryId)
                }
                self.fileUploadedCount = 0
            }
        }
    }
}
