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

public protocol UploadNotifiable {
    /// Notify the user that we have not enough storage to start an upload.
    func sendNotEnoughSpaceForUpload(filename: String)

    /// Send a local notification if some error is preventing the upload
    func sendPausedNotificationIfNeeded()

    /// Send a local notification that n files were uploaded
    func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult)
}

extension UploadQueue: UploadNotifiable {
    public func sendNotEnoughSpaceForUpload(filename: String) {
        DispatchQueue.main.async {
            @InjectService var notificationsHelper: NotificationsHelper
            notificationsHelper.sendNotEnoughSpaceForUpload(filename: filename)
        }
    }

    public func sendPausedNotificationIfNeeded() {
        dispatchQueue.async {
            if !self.pausedNotificationSent {
                NotificationsHelper.sendPausedUploadQueueNotification()
                self.pausedNotificationSent = true
            }
        }
    }

    public func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult) {
        guard let uploadFile = result.uploadFile, uploadFile.error != .taskRescheduled else {
            return
        }
        
        //TODO: Query realm
        fileUploadedCount += (uploadFile.error == nil ? 1 : 0)
        if let error = uploadFile.error,
           error != .networkError && error != .taskCancelled && error != .taskRescheduled {
            let uploadedFileName = result.driveFile?.name ?? uploadFile.name
            NotificationsHelper.sendUploadError(filename: uploadedFileName,
                                                parentId: uploadFile.parentDirectoryId,
                                                error: error)
            if operationQueue.operationCount == 0 {
                fileUploadedCount = 0
            }
        } else if operationQueue.operationCount == 0 {
            // In some cases fileUploadedCount can be == 1 but the result.uploadFile isn't necessary the last file *successfully* uploaded
            if fileUploadedCount == 1 && uploadFile.error == nil {
                let uploadedFileName = result.driveFile?.name ?? uploadFile.name
                NotificationsHelper.sendUploadDoneNotification(filename: uploadedFileName,
                                                               parentId: uploadFile.parentDirectoryId)
            } else if fileUploadedCount > 0 {
                NotificationsHelper.sendUploadDoneNotification(uploadCount: fileUploadedCount,
                                                               parentId: uploadFile.parentDirectoryId)
            }
            fileUploadedCount = 0
        }
    }
}
