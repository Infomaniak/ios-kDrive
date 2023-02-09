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

import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import RealmSwift
import Sentry

protocol UploadPublishable {
    func publishUploadCount(withParent parentId: Int,
                            userId: Int,
                            driveId: Int,
                            using realm: Realm)

    func publishUploadCountInParent(parentId: Int,
                                    userId: Int,
                                    driveId: Int,
                                    using realm: Realm)

    func publishUploadCountInDrive(userId: Int,
                                   driveId: Int,
                                   using realm: Realm)

    func publishFileUploaded(result: UploadCompletionResult)
}

// MARK: - Publish

extension UploadQueue: UploadPublishable {
    func publishUploadCount(withParent parentId: Int,
                            userId: Int,
                            driveId: Int,
                            using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        realm.refresh()
        publishUploadCountInParent(parentId: parentId, userId: userId, driveId: driveId, using: realm)
        publishUploadCountInDrive(userId: userId, driveId: driveId, using: realm)
    }

    func publishUploadCountInParent(parentId: Int,
                                    userId: Int,
                                    driveId: Int,
                                    using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        let uploadCount = getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId, using: realm).count
        observations.didChangeUploadCountInParent.values.forEach { closure in
            closure(parentId, uploadCount)
        }
    }

    func publishUploadCountInDrive(userId: Int,
                                   driveId: Int,
                                   using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        let uploadCount = getUploadingFiles(userId: userId, driveId: driveId, using: realm).count
        observations.didChangeUploadCountInDrive.values.forEach { closure in
            closure(driveId, uploadCount)
        }
    }

    func publishFileUploaded(result: UploadCompletionResult) {
        sendFileUploadedNotificationIfNeeded(with: result)
        observations.didUploadFile.values.forEach { closure in
            closure(result.uploadFile, result.driveFile)
        }
    }
    
    private func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult) {
        fileUploadedCount += (result.uploadFile.error == nil ? 1 : 0)
        if let error = result.uploadFile.error,
           error != .networkError && error != .taskCancelled && error != .taskRescheduled {
            let uploadedFileName = result.driveFile?.name ?? result.uploadFile.name
            NotificationsHelper.sendUploadError(filename: uploadedFileName,
                                                parentId: result.uploadFile.parentDirectoryId,
                                                error: error)
            if operationQueue.operationCount == 0 {
                fileUploadedCount = 0
            }
        } else if operationQueue.operationCount == 0 {
            // In some cases fileUploadedCount can be == 1 but the result.uploadFile isn't necessary the last file *successfully* uploaded
            if fileUploadedCount == 1 && result.uploadFile.error == nil {
                let uploadedFileName = result.driveFile?.name ?? result.uploadFile.name
                NotificationsHelper.sendUploadDoneNotification(filename: uploadedFileName,
                                                               parentId: result.uploadFile.parentDirectoryId)
            } else if fileUploadedCount > 0 {
                NotificationsHelper.sendUploadDoneNotification(uploadCount: fileUploadedCount,
                                                               parentId: result.uploadFile.parentDirectoryId)
            }
            fileUploadedCount = 0
        }
    }
}
