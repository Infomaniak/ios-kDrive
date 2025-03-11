/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
    /// Send a local notification that the system has paused the upload.
    func sendPausedNotificationIfNeeded()

    /// Send a local notification that n files were uploaded, or send a specific error message if in error state
    func sendFileUploadStateNotificationIfNeeded(with result: UploadCompletionResult)
}

extension UploadService: UploadNotifiable {
    public func sendPausedNotificationIfNeeded() {
        Log.uploadQueue("sendPausedNotificationIfNeeded")
        serialQueue.async { [weak self] in
            guard let self else { return }
            if !pausedNotificationSent {
                notificationHelper.sendPausedUploadQueueNotification()
                pausedNotificationSent = true
            }
        }
    }

    public func sendFileUploadStateNotificationIfNeeded(with result: UploadCompletionResult) {
        Log.uploadQueue("sendFileUploadStateNotificationIfNeeded")
        serialQueue.async { [weak self] in
            guard let self else { return }
            guard let uploadFile = result.uploadFile,
                  uploadFile.error != .taskRescheduled,
                  uploadFile.error != .taskCancelled,
                  !uploadFile.ownedByFileProvider else {
                return
            }

            fileUploadedCount += (uploadFile.error == nil ? 1 : 0)
            let currentOperationCount = operationCount
            if let error = uploadFile.error {
                let uploadedFileName = result.driveFile?.name ?? uploadFile.name
                if error.code == DriveError.LocalCode.errorDeviceStorage.rawValue {
                    notificationHelper.sendNotEnoughSpaceForUpload(filename: uploadedFileName)
                } else {
                    notificationHelper.sendGenericUploadError(filename: uploadedFileName,
                                                              parentId: uploadFile.parentDirectoryId,
                                                              error: error,
                                                              uploadFileId: uploadFile.id)
                }

                if currentOperationCount == 0 {
                    fileUploadedCount = 0
                }
            } else if currentOperationCount == 0 {
                // In some cases fileUploadedCount can be == 1 but the result.uploadFile isn't necessary the last file
                // *successfully* uploaded
                if fileUploadedCount == 1 && uploadFile.error == nil {
                    let uploadedFileName = result.driveFile?.name ?? uploadFile.name
                    notificationHelper.sendUploadDoneNotification(filename: uploadedFileName,
                                                                  parentId: uploadFile.parentDirectoryId)
                } else if fileUploadedCount > 0 {
                    notificationHelper.sendUploadDoneNotification(uploadCount: fileUploadedCount,
                                                                  parentId: uploadFile.parentDirectoryId)
                }
                fileUploadedCount = 0
            }
        }
    }
}
