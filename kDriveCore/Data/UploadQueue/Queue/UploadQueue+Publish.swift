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
                            driveId: Int)

    func publishUploadCountInParent(parentId: Int,
                                    userId: Int,
                                    driveId: Int)

    func publishUploadCountInDrive(userId: Int,
                                   driveId: Int)

    func publishFileUploaded(result: UploadCompletionResult)
}

// MARK: - Publish

extension UploadQueue: UploadPublishable {
    func publishUploadCount(withParent parentId: Int,
                            userId: Int,
                            driveId: Int) {
        UploadQueueLog("publishUploadCount")
        self.serialQueue.async { [unowned self] in
            self.publishUploadCountInParent(parentId: parentId, userId: userId, driveId: driveId)
            self.publishUploadCountInDrive(userId: userId, driveId: driveId)
        }
    }

    func publishUploadCountInParent(parentId: Int,
                                    userId: Int,
                                    driveId: Int) {
        UploadQueueLog("publishUploadCountInParent")
        self.serialQueue.async { [unowned self] in
            try? self.transactionWithUploadRealm { realm in
                let uploadCount = self.getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId, using: realm).count
                self.observations.didChangeUploadCountInParent.values.forEach { closure in
                    DispatchQueue.main.async {
                        closure(parentId, uploadCount)
                    }
                }
            }
        }
    }

    func publishUploadCountInDrive(userId: Int,
                                   driveId: Int) {
        UploadQueueLog("publishUploadCountInDrive")
        self.serialQueue.async { [unowned self] in
            try? self.transactionWithUploadRealm { realm in
                let uploadCount = self.getUploadingFiles(userId: userId, driveId: driveId, using: realm).count
                self.observations.didChangeUploadCountInDrive.values.forEach { closure in
                    DispatchQueue.main.async {
                        closure(driveId, uploadCount)
                    }
                }
            }
        }
    }

    func publishFileUploaded(result: UploadCompletionResult) {
        UploadQueueLog("publishFileUploaded")
        self.sendFileUploadedNotificationIfNeeded(with: result)
        self.serialQueue.async { [unowned self] in
            self.observations.didUploadFile.values.forEach { closure in
                guard let uploadFile = result.uploadFile, uploadFile.isInvalidated == false else {
                    return
                }

                DispatchQueue.main.async {
                    closure(uploadFile, result.driveFile)
                }
            }
        }
    }
}