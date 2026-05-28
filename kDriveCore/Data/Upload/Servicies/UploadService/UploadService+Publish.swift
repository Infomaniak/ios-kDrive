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
import InfomaniakCore
import RealmSwift

public protocol UploadPublishable {
    func publishUploadCount(withParent parentId: Int,
                            userId: Int,
                            driveId: Int)

    func publishUploadCountInParent(parentId: Int,
                                    userId: Int,
                                    driveId: Int)

    func publishUploadCountInDrive(userId: Int,
                                   driveId: Int)

    func publishFileUploaded(result: UploadCompletionResult)

    func publishQueueSuspended(queueName: String)
    func publishQueueResumed(queueName: String)
}

// MARK: - Publish

extension UploadService: UploadPublishable {
    public func publishUploadCount(withParent parentId: Int,
                                   userId: Int,
                                   driveId: Int) {
        Log.uploadQueue("publishUploadCount")
        serialEventQueue.async { [weak self] in
            guard let self else { return }
            publishUploadCountInParent(parentId: parentId, userId: userId, driveId: driveId)
            publishUploadCountInDrive(userId: userId, driveId: driveId)
        }
    }

    public func publishUploadCountInParent(parentId: Int,
                                           userId: Int,
                                           driveId: Int) {
        Log.uploadQueue("publishUploadCountInParent")
        serialEventQueue.async { [weak self] in
            guard let self else { return }

            let uploadCount = getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId).count
            for closure in observations.didChangeUploadCountInParent.values {
                Task { @MainActor in
                    closure(parentId, uploadCount)
                }
            }
        }
    }

    public func publishUploadCountInDrive(userId: Int,
                                          driveId: Int) {
        Log.uploadQueue("publishUploadCountInDrive")
        serialEventQueue.async { [weak self] in
            guard let self else { return }
            let uploadCount = getUploadingFiles(userId: userId, driveId: driveId).count
            for closure in observations.didChangeUploadCountInDrive.values {
                Task { @MainActor in
                    closure(driveId, uploadCount)
                }
            }
        }
    }

    public func publishFileUploaded(result: UploadCompletionResult) {
        Log.uploadQueue("publishFileUploaded")
        logFileUploadedWithSuccess(for: result.uploadFile)
        sendFileUploadStateNotificationIfNeeded(with: result)
        serialEventQueue.async { [weak self] in
            guard let self else { return }
            for closure in observations.didUploadFile.values {
                guard let uploadFile = result.uploadFile, !uploadFile.isInvalidated else {
                    continue
                }

                Task { @MainActor in
                    closure(uploadFile, result.driveFile)
                }
            }
        }
    }

    public func publishQueueSuspended(queueName: String) {
        Log.uploadQueue("Queue \(queueName) SUSPENDED")
        serialEventQueue.async { [weak self] in
            guard let self else { return }
            guard !suspendedQueueNames.contains(queueName) else { return }
            suspendedQueueNames.append(queueName)
        }
    }

    public func publishQueueResumed(queueName: String) {
        Log.uploadQueue("Queue \(queueName) RESUMED")
        serialEventQueue.async { [weak self] in
            guard let self else { return }
            suspendedQueueNames.removeAll { $0 == queueName }
        }
    }

    // MARK: Private

    func logFileUploadedWithSuccess(for uploadFile: UploadFile?) {
        Task {
            let metadata: [String: Any]
            if let uploadFile {
                assert(uploadFile.realm == nil || uploadFile.isFrozen, "Expecting something that can be used concurrently")
                metadata = ["fid": uploadFile.id,
                            "uploadDate": "\(String(describing: uploadFile.uploadDate))",
                            "taskCreationDate": "\(String(describing: uploadFile.taskCreationDate))",
                            "type": "\(uploadFile.convertedType)"]
            } else {
                metadata = ["no_uploadFile": ""]
            }
            SentryDebug.uploadOperationCompletedWithSuccess(metadata)
        }
    }
}
