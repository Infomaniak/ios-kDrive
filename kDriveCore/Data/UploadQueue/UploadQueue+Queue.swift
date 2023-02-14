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

public protocol UploadQueueable {
    func addToQueueFromRealm()

    func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?)

    func suspendAllOperations()

    func resumeAllOperations()

    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    func retry(_ file: UploadFile)

    func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelAllOperations()

    func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelRunningOperations()

    func cancel(_ file: UploadFile)
}

// MARK: - Publish

extension UploadQueue: UploadQueueable {
    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            completionHandler()
        }
    }

    public func addToQueueFromRealm() {
        foregroundSession.getTasksWithCompletionHandler { _, uploadTasks, _ in
            self.dispatchQueue.async {
                let uploadingFiles = self.realm.objects(UploadFile.self)
                    .filter("uploadDate = nil AND maxRetryCount > 0")
                    .sorted(byKeyPath: "taskCreationDate")
                autoreleasepool {
                    uploadingFiles.forEach { uploadFile in
                        // BEFORE
                        // If the upload file has a session URL but it's foreground and doesn't exist anymore (e.g. app was killed), we add it again
                        /*if uploadFile.sessionUrl.isEmpty || (!uploadFile.sessionUrl.isEmpty && uploadFile.sessionId == self.foregroundSession.identifier && !uploadTasks.contains(where: { $0.originalRequest?.url?.absoluteString == uploadFile.sessionUrl })) {
                            self.addToQueue(file: uploadFile, itemIdentifier: nil, using: self.realm)
                        }*/
                        
                        // NOW k(eep)i(t)s(uper)s(imple)
                        // Try to ad it back in. NOOP if already in there.
                        self.addToQueue(file: uploadFile, itemIdentifier: nil, using: self.realm)
                    }
                }
            }
        }
    }

    public func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        dispatchQueue.async {
            self.addToQueue(file: file, itemIdentifier: itemIdentifier, using: self.realm)
        }
    }

    public func suspendAllOperations() {
        forceSuspendQueue = true
        operationQueue.isSuspended = true
    }

    public func resumeAllOperations() {
        forceSuspendQueue = false
        operationQueue.isSuspended = shouldSuspendQueue
    }

    public func cancelAllOperations() {
        operationQueue.cancelAllOperations()
    }

    public func cancelRunningOperations() {
        operationQueue.operations.filter(\.isExecuting).forEach { $0.cancel() }
    }

    public func cancel(_ file: UploadFile) {
        dispatchQueue.async { [fileId = file.id,
                               parentId = file.parentDirectoryId,
                               userId = file.userId,
                               driveId = file.driveId,
                               realm = realm!] in
                let operation = self.operationsInQueue[fileId]
                if operation?.isExecuting != true,
                   let toDelete = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId) {
                    let publishedToDelete = UploadFile(value: toDelete)
                    publishedToDelete.error = .taskCancelled
                    try? realm.safeWrite {
                        realm.delete(toDelete)
                    }
                    self.publishFileUploaded(result: UploadCompletionResult(uploadFile: publishedToDelete, driveFile: nil))
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: realm)
                }
                operation?.cancel()
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        dispatchQueue.async {
            self.suspendAllOperations()
            let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                        userId: userId,
                                                        driveId: driveId,
                                                        using: self.realm)
            uploadingFiles.forEach { file in
                if !file.isInvalidated,
                   let operation = self.operationsInQueue[file.id] {
                    operation.cancel()
                }
            }
            try? self.realm.safeWrite {
                self.realm.delete(uploadingFiles)
            }
            self.publishUploadCount(withParent: parentId,
                                    userId: userId,
                                    driveId: driveId,
                                    using: self.realm)
            self.resumeAllOperations()
        }
    }

    public func retry(_ file: UploadFile) {
        let safeFile = ThreadSafeReference(to: file)
        dispatchQueue.async {
            guard let file = self.realm.resolve(safeFile), !file.isInvalidated else { return }
            try? self.realm.safeWrite {
                file.error = nil
                file.maxRetryCount = UploadFile.defaultMaxRetryCount
            }
            self.addToQueue(file: file, using: self.realm)
            self.publishProgress(0, for: file.id)
        }
    }

    public func retryAllOperations(withParent parentId: Int,
                                   userId: Int,
                                   driveId: Int) {
        dispatchQueue.async {
            let failedUploadFiles = self.getUploadingFiles(withParent: parentId,
                                                           userId: userId,
                                                           driveId: driveId,
                                                           using: self.realm).filter("_error != nil")
            try? self.realm.safeWrite {
                failedUploadFiles.forEach { file in
                    file.error = nil
                    file.maxRetryCount = UploadFile.defaultMaxRetryCount
                }
            }
            failedUploadFiles.forEach {
                self.addToQueue(file: $0, using: self.realm)
                self.publishProgress(0, for: $0.id)
            }
        }
    }

    // MARK: - Private methods

    private func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil, using realm: Realm) {
        guard !file.isInvalidated && operationsInQueue[file.id] == nil && file.maxRetryCount > 0 else {
            return
        }

        if !file.isManagedByRealm {
            // Save drive and directory
            UserDefaults.shared.lastSelectedUser = file.userId
            UserDefaults.shared.lastSelectedDrive = file.driveId
            UserDefaults.shared.lastSelectedDirectory = file.parentDirectoryId
        }

        try? realm.safeWrite {
            if !file.isManagedByRealm {
                realm.add(file, update: .modified)
            }
            file.name = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if file.error != nil {
                file.error = nil
            }
        }

        OperationQueueHelper.disableIdleTimer(true)

        let operation = UploadOperation(file: file, urlSession: bestSession, itemIdentifier: itemIdentifier)

        operation.queuePriority = file.priority
        operation.completionBlock = { [unowned self, parentId = file.parentDirectoryId, fileId = file.id, userId = file.userId, driveId = file.driveId] in
            self.dispatchQueue.async {
                self.operationsInQueue.removeValue(forKey: fileId)
                if operation.result.uploadFile.error != .taskRescheduled {
                    self.publishFileUploaded(result: operation.result)
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: self.realm)
                    OperationQueueHelper.disableIdleTimer(false, queue: self.operationsInQueue)
                }
            }
        }
        operationQueue.addOperation(operation as Operation)
        operationsInQueue[file.id] = operation

        publishUploadCount(withParent: file.parentDirectoryId, userId: file.userId, driveId: file.driveId, using: realm)
    }
}
