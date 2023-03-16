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
    func rebuildUploadQueueFromObjectsInRealm(_ caller: StaticString)

    func saveToRealmAndAddToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?) -> UploadOperationable?

    func suspendAllOperations()

    func resumeAllOperations()

    /// Wait for all (started or not) enqueued operations to finish.
    func waitForCompletion(_ completionHandler: @escaping () -> Void)

    // Retry to upload a specific file, this re-enqueue the task.
    func retry(_ fileId: String)

    // Retry all uploads within a specified graph, this re-enqueue the tasks.
    func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int)

    /// Cancel all running operations, regardless of state
    func cancelRunningOperations()

    /// Cancel an upload from an UploadFile. The UploadFile is removed and a matching operation is removed.
    func cancel(_ file: UploadFile)

    /// Clean errors linked to any upload operation in base. Does not restart the operations.
    ///
    /// Also make sure that UploadFiles initiated in FileManager will restart at next retry.
    func cleanNetworkAndLocalErrorsForAllOperations()
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
        let operation = self.operation(fileId: fileId)
        return operation
    }

    public func rebuildUploadQueueFromObjectsInRealm(_ caller: StaticString = #function) {
        UploadQueueLog("rebuildUploadQueueFromObjectsInRealm caller:\(caller)")
        concurrentQueue.sync {
            var uploadingFileIds = [String]()
            try? self.transactionWithUploadRealm { realm in
                // Not uploaded yet, And can retry, And not initiated from the Files.app
                let uploadingFiles = realm.objects(UploadFile.self)
                    .filter("uploadDate = nil AND maxRetryCount > 0 AND initiatedFromFileManager = false")
                    .sorted(byKeyPath: "taskCreationDate")
                uploadingFileIds = uploadingFiles.map(\.id)
                UploadQueueLog("rebuildUploadQueueFromObjectsInRealm uploads to restart:\(uploadingFileIds.count)")
            }

            let batches = uploadingFileIds.chunked(into: 100)
            UploadQueueLog("batched count:\(batches.count)")
            for batch in batches {
                UploadQueueLog("rebuildUploadQueueFromObjectsInRealm in batch")
                try? self.transactionWithUploadRealm { realm in
                    batch.forEach { fileId in
                        guard let file = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId),
                              !file.isInvalidated else {
                            return
                        }
                        self.addToQueueIfNecessary(file: file, using: realm)
                    }
                }
                self.resumeAllOperations()
            }

            UploadQueueLog("rebuildUploadQueueFromObjectsInRealm exit")
        }
    }

    @discardableResult
    public func saveToRealmAndAddToQueue(file: UploadFile,
                                         itemIdentifier: NSFileProviderItemIdentifier? = nil) -> UploadOperationable? {
        UploadQueueLog("saveToRealmAndAddToQueue fid:\(file.id)")
        assert(!file.isManagedByRealm, "we expect the file to be outside of realm at the moment")

        // Save drive and directory
        UserDefaults.shared.lastSelectedUser = file.userId
        UserDefaults.shared.lastSelectedDrive = file.driveId
        UserDefaults.shared.lastSelectedDirectory = file.parentDirectoryId

        file.name = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if file.error != nil {
            file.error = nil
        }

        // Keep a detached file for processing it later
        let detachedFile = file.detached()
        try? transactionWithUploadRealm { realm in
            UploadQueueLog("save fid:\(file.id)")
            try? realm.safeWrite {
                realm.add(file, update: .modified)
            }
            UploadQueueLog("did save fid:\(file.id)")
        }

        // Process adding a detached file to the uploadQueue
        var uploadOperation: UploadOperation?
        try? transactionWithUploadRealm { realm in
            uploadOperation = self.addToQueue(file: detachedFile, itemIdentifier: itemIdentifier, using: realm)
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
        let fileId = file.id
        let userId = file.userId
        let parentId = file.parentDirectoryId
        let driveId = file.driveId

        concurrentQueue.async {
            if let operation = self.keyedUploadOperations.getObject(forKey: fileId) {
                UploadQueueLog("operation to cancel:\(operation)")
                operation.cleanUploadFileSession(file: nil)
                operation.cancel()
            }
            self.keyedUploadOperations.removeObject(forKey: fileId)

            try? self.transactionWithUploadRealm { realm in
                if let toDelete = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId), !toDelete.isInvalidated {
                    UploadQueueLog("find UploadFile to delete :\(fileId)")
                    let publishedToDelete = UploadFile(value: toDelete)
                    publishedToDelete.error = .taskCancelled
                    try? realm.safeWrite {
                        realm.delete(toDelete)
                    }

                    UploadQueueLog("publishFileUploaded fid:\(fileId)")
                    self.publishFileUploaded(result: UploadCompletionResult(uploadFile: publishedToDelete, driveFile: nil))
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
                } else {
                    UploadQueueLog("could not find file to cancel:\(fileId)", level: .error)
                }
            }
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        UploadQueueLog("cancelAllOperations parentId:\(parentId)")
        concurrentQueue.async {
            UploadQueueLog("suspend queue")
            self.suspendAllOperations()

            var uploadingFilesIds = [String]()
            try? self.transactionWithUploadRealm { realm in
                let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                            userId: userId,
                                                            driveId: driveId,
                                                            using: realm)
                UploadQueueLog("cancelAllOperations count:\(uploadingFiles.count) parentId:\(parentId)")
                uploadingFilesIds = uploadingFiles.map(\.id)
                UploadQueueLog("cancelAllOperations IDS count:\(uploadingFilesIds.count) parentId:\(parentId)")

                // Delete all the linked UploadFiles from Realm. This is fast.
                try? realm.safeWrite {
                    UploadQueueLog("delete all matching files count:\(uploadingFiles.count) parentId:\(parentId)")
                    realm.delete(uploadingFiles)
                }
                UploadQueueLog("Done deleting all matching files for parentId:\(parentId)")
            }

            // Remove in batches from upload queue. This may take a while.
            let batches = uploadingFilesIds.chunked(into: 100)
            for fileIds in batches {
                autoreleasepool {
                    fileIds.forEach { id in
                        // Cancel operation if any
                        if let operation = self.keyedUploadOperations.getObject(forKey: id) {
                            operation.cancel()
                        }
                        self.keyedUploadOperations.removeObject(forKey: id)
                    }
                }
            }

            try? self.transactionWithUploadRealm { _ in
                self.publishUploadCount(withParent: parentId,
                                        userId: userId,
                                        driveId: driveId)
            }

            UploadQueueLog("cancelAllOperations finished")
            self.resumeAllOperations()
        }
    }

    public func cleanNetworkAndLocalErrorsForAllOperations() {
        UploadQueueLog("cleanErrorsForAllOperations")
        concurrentQueue.sync {
            try? self.transactionWithUploadRealm { realm in
                // UploadFile with an error, Or no more retry, Or is initiatedFromFileManager
                let failedUploadFiles = realm.objects(UploadFile.self)
                    .filter("_error != nil OR maxRetryCount <= 0 OR initiatedFromFileManager = true")
                    .filter { file in
                        guard let error = file.error else {
                            return false
                        }

                        return (error.type != .serverError)
                    }
                UploadQueueLog("will clean errors for uploads:\(failedUploadFiles.count)")

                try? realm.safeWrite {
                    failedUploadFiles.forEach { file in
                        file.clearErrorsForRetry()
                    }
                }
                UploadQueueLog("cleaned errors on \(failedUploadFiles.count) files")
            }
        }
    }

    public func retry(_ fileId: String) {
        UploadQueueLog("retry fid:\(fileId)")
        concurrentQueue.async {
            try? self.transactionWithUploadRealm { realm in
                guard let file = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId), !file.isInvalidated else {
                    UploadQueueLog("file invalidated in\(#function) line:\(#line) fid:\(fileId)")
                    return
                }

                // Remove operation from tracking
                if let operation = self.operation(fileId: fileId) {
                    operation.cancel()
                    self.keyedUploadOperations.removeObject(forKey: fileId)
                }

                // Clean error in base
                try? realm.safeWrite {
                    file.clearErrorsForRetry()
                }
            }

            // re-enqueue UploadOperation
            try? self.transactionWithUploadRealm { realm in
                guard let file = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId), !file.isInvalidated else {
                    UploadQueueLog("file invalidated in\(#function) line:\(#line) fid:\(fileId)")
                    return
                }

                self.addToQueue(file: file, using: realm)
            }

            self.resumeAllOperations()
        }
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        UploadQueueLog("retryAllOperations parentId:\(parentId)")

        concurrentQueue.async {
            let failedFileIds = self.getFailedFileIds(parentId: parentId, userId: userId, driveId: driveId)
            let batches = failedFileIds.chunked(into: 100)
            UploadQueueLog("batches:\(batches.count)")

            self.resumeAllOperations()

            for batch in batches {
                UploadQueueLog("in batch")
                // Cancel Operation if any and reset errors
                self.cancelAnyInBatch(batch)

                // Second transaction to enqueue the UploadFile to the OperationQueue
                self.enqueueAnyInBatch(batch)
            }
        }
    }

    // MARK: - Private methods

    private func getFailedFileIds(parentId: Int, userId: Int, driveId: Int) -> [String] {
        var failedFileIds = [String]()
        try? transactionWithUploadRealm { realm in
            UploadQueueLog("retryAllOperations in dispatchQueue parentId:\(parentId)")
            let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                        userId: userId,
                                                        driveId: driveId,
                                                        using: realm)
            UploadQueueLog("uploading:\(uploadingFiles.count)")
            let failedUploadFiles = uploadingFiles.filter("_error != nil OR maxRetryCount <= 0 OR initiatedFromFileManager = true")
            failedFileIds = failedUploadFiles.map(\.id)
            UploadQueueLog("retying:\(failedFileIds.count)")
        }
        return failedFileIds
    }

    private func cancelAnyInBatch(_ batch: [String]) {
        try? transactionWithUploadRealm { realm in
            batch.forEach { fileId in
                // Cancel operation if any
                if let operation = self.operation(fileId: fileId) {
                    operation.cancel()
                    self.keyedUploadOperations.removeObject(forKey: fileId)
                }

                // Clean errors in db file
                guard let file = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId), !file.isInvalidated else {
                    UploadQueueLog("file invalidated fid:\(fileId) at\(#line)")
                    return
                }
                try? realm.safeWrite {
                    file.clearErrorsForRetry()
                }
            }
        }
    }

    private func enqueueAnyInBatch(_ batch: [String]) {
        try? transactionWithUploadRealm { realm in
            batch.forEach { fileId in
                guard let file = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId), !file.isInvalidated else {
                    UploadQueueLog("file invalidated fid:\(fileId) at\(#line)")
                    return
                }

                self.addToQueueIfNecessary(file: file, using: realm)
            }
        }
    }

    private func operation(fileId: String) -> UploadOperationable? {
        UploadQueueLog("operation fileId:\(fileId)")
        guard let operation = keyedUploadOperations.getObject(forKey: fileId),
              !operation.isCancelled,
              !operation.isFinished else {
            return nil
        }
        return operation
    }

    private func addToQueueIfNecessary(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil,
                                       using realm: Realm) {
        guard !file.isInvalidated else {
            return
        }

        UploadQueueLog("rebuildUploadQueueFromObjectsInRealm fid:\(file.id)")
        guard let _ = operation(fileId: file.id) else {
            UploadQueueLog("rebuildUploadQueueFromObjectsInRealm ADD fid:\(file.id)")
            addToQueue(file: file, itemIdentifier: nil, using: realm)
            return
        }

        UploadQueueLog("rebuildUploadQueueFromObjectsInRealm NOOP fid:\(file.id)")
    }

    @discardableResult
    private func addToQueue(file: UploadFile,
                            itemIdentifier: NSFileProviderItemIdentifier? = nil,
                            using realm: Realm) -> UploadOperation? {
        guard !file.isInvalidated,
              file.maxRetryCount > 0,
              keyedUploadOperations.getObject(forKey: file.id) == nil else {
            UploadQueueLog("invalid file in \(#function)", level: .error)
            return nil
        }

        let fileId = file.id
        let parentId = file.parentDirectoryId
        let userId = file.userId
        let driveId = file.driveId
        let priority = file.priority
        OperationQueueHelper.disableIdleTimer(true)

        let operation = UploadOperation(fileId: fileId, urlSession: bestSession, itemIdentifier: itemIdentifier)
        operation.queuePriority = priority
        operation.completionBlock = { [unowned self] in
            UploadQueueLog("operation.completionBlock for operation:\(operation) fid:\(fileId)")
            self.keyedUploadOperations.removeObject(forKey: fileId)
            if let error = operation.result.uploadFile?.error,
               error == .taskRescheduled || error == .taskCancelled {
                UploadQueueLog("skipping task")
                return
            }

            self.publishFileUploaded(result: operation.result)
            self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
            OperationQueueHelper.disableIdleTimer(false, hasOperationsInQueue: self.keyedUploadOperations.isEmpty)
        }

        UploadQueueLog("add operation :\(operation) fid:\(fileId)")
        operationQueue.addOperation(operation as Operation)

        keyedUploadOperations.setObject(operation, key: fileId)
        publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)

        return operation
    }
}
