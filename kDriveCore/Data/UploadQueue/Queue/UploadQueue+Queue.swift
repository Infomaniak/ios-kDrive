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
    func getOperation(forFileId fileId: String) -> UploadOperationable?

    /// Read database to enqueue all non finished upload tasks.
    func rebuildUploadQueueFromObjectsInRealm()

    func saveToRealmAndAddtoQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?) -> UploadOperationable?

    func suspendAllOperations()

    func resumeAllOperations()

    /// Wait for all (started or not) enqueued operations to finish.
    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    // Retry to upload a specific file, this re-enqueue the task.
    func retry(_ file: UploadFile)

    // Retry all uploads within a specified graph, this re-enqueue the tasks.
    func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    /// Cancel all running operations, regardless of state
    func cancelRunningOperations()

    /// Cancel an upload from an UploadFile. The UploadFile is removed and a matching operation is removed.
    func cancel(_ file: UploadFile)

    /// Clean errors linked to any upload operation in base. Does not restart the operations.
    func cleanErrorsForAllOperations()
}

// MARK: - Publish

extension UploadQueue: UploadQueueable {
    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        UploadQueueLog("waitForCompletion")
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            UploadQueueLog("🎉 AllOperationsAreFinished")
            completionHandler()
        }
    }

    public func getOperation(forFileId fileId: String) -> UploadOperationable? {
        UploadQueueLog("getOperation fid:\(fileId)")
        var operation: UploadOperationable?
        dispatchQueue.sync {
            operation = self.operation(fileId: fileId)
        }
        return operation
    }

    public func rebuildUploadQueueFromObjectsInRealm() {
        UploadQueueLog("rebuildUploadQueueFromObjectsInRealm")
        self.dispatchQueue.sync {
            self.realm.refresh()

            let uploadingFiles = self.realm.objects(UploadFile.self)
                .filter("uploadDate = nil AND maxRetryCount > 0")
                .sorted(byKeyPath: "taskCreationDate")
            UploadQueueLog("rebuildUploadQueueFromObjectsInRealm uploads to restart:\(uploadingFiles.count)")

            let batches = Array(uploadingFiles).chunked(into: 100)
            UploadQueueLog("batched count:\(batches.count)")
            for batch in batches {
                autoreleasepool {
                    UploadQueueLog("rebuildUploadQueueFromObjectsInRealm in batch")
                    batch.forEach { uploadFile in
                        self.addToQueueIfNecessary(file: uploadFile, using: self.realm)
                    }
                    self.resumeAllOperations()
                }
            }

            UploadQueueLog("rebuildUploadQueueFromObjectsInRealm exit")
        }
    }

    @discardableResult
    public func saveToRealmAndAddtoQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil) -> UploadOperationable? {
        UploadQueueLog("saveToRealmAndAddtoQueue fid:\(file.id)")
        assert(!file.isManagedByRealm, "we expect the file to be outside of realm at the moment")

        // Save drive and directory
        UserDefaults.shared.lastSelectedUser = file.userId
        UserDefaults.shared.lastSelectedDrive = file.driveId
        UserDefaults.shared.lastSelectedDirectory = file.parentDirectoryId

        file.name = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if file.error != nil {
            file.error = nil
        }

        let detachedFile = file.detached()
        BackgroundRealm.uploads.execute { realm in
            UploadQueueLog("save fid:\(file.id)")
            try? realm.write {
                realm.add(file, update: .modified)
            }
            UploadQueueLog("did save fid:\(file.id)")
        }

        var uploadOperation: UploadOperation?
        dispatchQueue.sync {
            uploadOperation = self.addToQueue(file: detachedFile, itemIdentifier: itemIdentifier, using: self.realm)
        }
        return uploadOperation
    }

    public func suspendAllOperations() {
        UploadQueueLog("suspendAllOperations")
        forceSuspendQueue = true
        operationQueue.isSuspended = true
    }

    public func resumeAllOperations() {
        UploadQueueLog("resumeAllOperations")
        forceSuspendQueue = false
        operationQueue.isSuspended = shouldSuspendQueue
    }

    public func cancelRunningOperations() {
        UploadQueueLog("cancelRunningOperations")
        operationQueue.operations.filter(\.isExecuting).forEach { $0.cancel() }
    }

    public func cancel(_ file: UploadFile) {
        UploadQueueLog("cancel fid:\(file.id)")
        dispatchQueue.async { [fileId = file.id,
                               parentId = file.parentDirectoryId,
                               userId = file.userId,
                               driveId = file.driveId,
                               realm = realm!] in
                if let operation = self.operationsInQueue[fileId] {
                    UploadQueueLog("operation to cancel:\(operation)")
                    DispatchQueue.global(qos: .background).async {
                        operation.cleanUploadFileSession(file: nil)
                        operation.cancel()
                    }
                }

                self.operationsInQueue.removeValue(forKey: fileId)

                if let toDelete = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId) {
                    UploadQueueLog("find UploadFile to delete :\(fileId)")
                    let publishedToDelete = UploadFile(value: toDelete)
                    publishedToDelete.error = .taskCancelled
                    try? realm.write {
                        realm.delete(toDelete)
                    }

                    UploadQueueLog("publishFileUploaded fid:\(fileId)")
                    self.publishFileUploaded(result: UploadCompletionResult(uploadFile: publishedToDelete, driveFile: nil))
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: realm)
                } else {
                    UploadQueueLog("could not find file to cancel:\(fileId)", level: .error)
                }
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        UploadQueueLog("cancelAllOperations parentId:\(parentId)")
        dispatchQueue.async {
            UploadQueueLog("suspend queue")
            self.suspendAllOperations()
            let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                        userId: userId,
                                                        driveId: driveId,
                                                        using: self.realm)
            UploadQueueLog("cancelAllOperations count:\(uploadingFiles.count) parentId:\(parentId)")
            let uploadingFilesIds = uploadingFiles.map(\.id)
            UploadQueueLog("cancelAllOperations IDS count:\(uploadingFilesIds.count) parentId:\(parentId)")

            // Delete all the linked UploadFiles from Realm. This is fast.
            autoreleasepool {
                try? self.realm.write {
                    UploadQueueLog("delete all matching files count:\(uploadingFiles.count) parentId:\(parentId)")
                    self.realm.delete(uploadingFiles)
                }
            }
            UploadQueueLog("Done deleting all matching files for parentId:\(parentId)")

            // Remove in batches from upload queue. This may take a while.
            let batches = Array(uploadingFilesIds).chunked(into: 100)
            for fileIds in batches {
                autoreleasepool {
                    UploadQueueLog("remove a chunk of file IDs from queue")
                    fileIds.forEach { id in
                        if let operation = self.operationsInQueue[id] {
                            operation.cancel()
                        }
                        self.operationsInQueue.removeValue(forKey: id)
                    }
                }
            }

            self.publishUploadCount(withParent: parentId,
                                    userId: userId,
                                    driveId: driveId,
                                    using: self.realm)

            UploadQueueLog("cancelAllOperations finished")
            self.resumeAllOperations()
        }
    }

    public func cleanErrorsForAllOperations() {
        UploadQueueLog("cleanErrorsForAllOperations")
        dispatchQueue.sync {
            let failedUploadFiles = self.realm.objects(UploadFile.self)
                .filter("_error != nil OR maxRetryCount == 0")
            UploadQueueLog("will clean errors for uploads:\(failedUploadFiles.count)")
            try? self.realm.write {
                failedUploadFiles.forEach { file in
                    file.error = nil
                    file.maxRetryCount = UploadFile.defaultMaxRetryCount
                }
            }
            UploadQueueLog("cleaned errors on \(failedUploadFiles.count) files")
        }
    }

    public func retry(_ file: UploadFile) {
        UploadQueueLog("retry fid:\(file.id)")
        let safeFile = ThreadSafeReference(to: file)
        dispatchQueue.async {
            guard let file = self.realm.resolve(safeFile), !file.isInvalidated else { return }

            if let operation = self.operation(fileId: file.id) {
                operation.cancel()
                self.operationsInQueue.removeValue(forKey: file.id)
            }

            try? self.realm.write {
                file.error = nil
                file.maxRetryCount = UploadFile.defaultMaxRetryCount
            }

            self.addToQueue(file: file, using: self.realm)
        }
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        UploadQueueLog("retryAllOperations parentId:\(parentId)")

        dispatchQueue.async {
            var files = [UploadFile]()
            BackgroundRealm.uploads.execute { realm in
                UploadQueueLog("retryAllOperations in dispatchQueue parentId:\(parentId)")
                let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                            userId: userId,
                                                            driveId: driveId,
                                                            using: realm)
                UploadQueueLog("uploading:\(uploadingFiles.count)")
                let failedUploadFiles = uploadingFiles.filter("_error != nil OR maxRetryCount == 0")
                UploadQueueLog("retying:\(failedUploadFiles.count)")
                files = Array(failedUploadFiles)
            }

            let batches = Array(files).chunked(into: 100)
            UploadQueueLog("batches:\(batches.count)")
            self.resumeAllOperations()

            for batch in batches {
                autoreleasepool {
                    BackgroundRealm.uploads.execute { realm in
                        do {
                            try realm.write {
                                batch.forEach { file in
                                    if let operation = self.operation(fileId: file.id) {
                                        operation.cancel()
                                        self.operationsInQueue.removeValue(forKey: file.id)
                                    }
                                    file.error = nil
                                    file.maxRetryCount = UploadFile.defaultMaxRetryCount
                                }
                                batch.forEach { file in
                                    self.addToQueueIfNecessary(file: file, using: realm)
                                }
                            }
                        } catch {
                            UploadQueueLog("retryAllOperations realm error:\(error)", level: .error)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Private methods

    private func operation(fileId: String) -> UploadOperationable? {
        UploadQueueLog("operation fileId:\(fileId)")
        guard let operation = operationsInQueue[fileId],
              operation.isCancelled == false,
              operation.isFinished == false else {
            return nil
        }
        return operation
    }

    private func addToQueueIfNecessary(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil, using realm: Realm) {
        UploadQueueLog("rebuildUploadQueueFromObjectsInRealm fid:\(file.id)")
        guard let _ = self.operation(fileId: file.id) else {
            UploadQueueLog("rebuildUploadQueueFromObjectsInRealm ADD fid:\(file.id)")
            self.addToQueue(file: file, itemIdentifier: nil, using: realm)
            return
        }
        
        UploadQueueLog("rebuildUploadQueueFromObjectsInRealm NOOP fid:\(file.id)")
    }

    @discardableResult
    private func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil, using realm: Realm) -> UploadOperation? {
        guard !file.isInvalidated && operationsInQueue[file.id] == nil && file.maxRetryCount > 0 else {
            UploadQueueLog("addToQueue isInvalidated:\(file.isInvalidated) operationsInQueue:\(operationsInQueue[file.id] != nil) maxRetryCount:\(file.maxRetryCount) fid:\(file.id)", level: .error)
            return nil
        }

        OperationQueueHelper.disableIdleTimer(true)

        // Needed so each UploadOperation is able to do a `transactionWithFile` reliably
        let refreshed = realm.refresh()
        UploadQueueLog("refreshed:\(refreshed) fid:\(file.id)")

        let operation = UploadOperation(file: file, urlSession: bestSession, itemIdentifier: itemIdentifier)
        operation.queuePriority = file.priority
        operation.completionBlock = { [unowned self, parentId = file.parentDirectoryId, fileId = file.id, userId = file.userId, driveId = file.driveId] in
            UploadQueueLog("operation.completionBlock fid:\(fileId)")
            self.dispatchQueue.sync {
                UploadQueueLog("completionBlock for operation:\(operation) fid:\(fileId)")
                self.operationsInQueue.removeValue(forKey: fileId)
                guard let error = operation.result.uploadFile?.error,
                      error != .taskRescheduled || error != .taskCancelled else {
                    UploadQueueLog("skipping task")
                    return
                }

                self.publishFileUploaded(result: operation.result)
                self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: self.realm)
                OperationQueueHelper.disableIdleTimer(false, queue: self.operationsInQueue)
            }
        }

        UploadQueueLog("add operation :\(operation) fid:\(file.id)")
        operationQueue.addOperation(operation as Operation)
        operationsInQueue[file.id] = operation

        publishUploadCount(withParent: file.parentDirectoryId, userId: file.userId, driveId: file.driveId, using: realm)

        return operation
    }
}
