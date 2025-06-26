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
    var pausedNotificationSent: Bool { get }

    func setPausedNotificationSent(_ newValue: Bool)

    func sendPausedNotificationIfNeeded()

    func sendFileUploadStateNotificationIfNeeded(with result: UploadCompletionResult)
}

extension UploadService: UploadNotifiable {
    public func setPausedNotificationSent(_ newValue: Bool) {
        Log.uploadQueue("setPausedNotificationSent newValue:\(newValue)")
        pausedNotificationSent = newValue
    }

    public func sendPausedNotificationIfNeeded() {
        Log.uploadQueue("sendPausedNotificationIfNeeded")
        guard !pausedNotificationSent else {
            return
        }

        notificationHelper.sendPausedUploadQueueNotification()
        pausedNotificationSent = true
    }

    public func sendFileUploadStateNotificationIfNeeded(with result: UploadCompletionResult) {
        Log.uploadQueue("sendFileUploadStateNotificationIfNeeded")
        serialEventQueue.async { [weak self] in
            guard let self else { return }
            guard let uploadFile = result.uploadFile,
                  uploadFile.error != .taskRescheduled,
                  uploadFile.error != .taskCancelled,
                  !uploadFile.ownedByFileProvider else {
                return
            }

            fileUploadedCount += (uploadFile.error == nil ? 1 : 0)
            let currentOperationCount = operationCount
            if uploadFile.error != nil {
                sendFileUploadStateNotificationErrorIfNeeded(
                    result: result,
                    uploadFile: uploadFile,
                    currentOperationCount: currentOperationCount
                )
            } else if currentOperationCount == 0 {
                sendFileUploadStateNotificationSuccessIfNeeded(uploadFile: uploadFile, result: result)
            }
        }
    }

    private func sendFileUploadStateNotificationErrorIfNeeded(
        result: UploadCompletionResult,
        uploadFile: UploadFile,
        currentOperationCount: Int
    ) {
        let uploadedFileName = result.driveFile?.name ?? uploadFile.name
        if let error = uploadFile.error {
            if error.code == DriveError.LocalCode.errorDeviceStorage.rawValue {
                notificationHelper.sendNotEnoughSpaceForUpload(filename: uploadedFileName)
            } else {
                fileUploadFailedCount += 1
                if currentOperationCount == 0 {
                    notificationHelper.sendFailedUpload(
                        failedUpload: fileUploadFailedCount,
                        totalUpload: fileUploadedCount + fileUploadFailedCount
                    )
                }
            }
        }
    }

    private func sendFileUploadStateNotificationSuccessIfNeeded(uploadFile: UploadFile, result: UploadCompletionResult) {
        if fileUploadedCount == 1 && uploadFile.error == nil {
            let uploadedFileName = result.driveFile?.name ?? uploadFile.name
            notificationHelper.sendUploadDoneNotification(filename: uploadedFileName,
                                                          parentId: uploadFile.parentDirectoryId)
        } else if fileUploadedCount > 0 {
            notificationHelper.sendUploadDoneNotification(uploadCount: fileUploadedCount,
                                                          parentId: uploadFile.parentDirectoryId)
        }
    }
}
