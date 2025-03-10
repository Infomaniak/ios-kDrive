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

import Algorithms
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import InfomaniakDI
import RealmSwift

// MARK: - Publish

extension UploadQueue: UploadQueueable {
    /// A query for the `UploadFiles` in the  __Main app__ context
    ///
    /// Not uploaded yet, can retry, not owned by `FileProvider`.
    static let appFilesToUploadQuery = "uploadDate = nil AND maxRetryCount > 0 AND ownedByFileProvider == false"

    /// A query for the `UploadFiles` in the  __FileProvider__ context
    ///
    /// Not uploaded yet, can retry, owned by `FileProvider`.
    static let fileProviderFilesToUploadQuery = "uploadDate = nil AND maxRetryCount > 0 AND ownedByFileProvider == true"

    /// Query to fetch `UploadFiles` for the current execution context
    var uploadFileQuery: String? {
        switch appContextService.context {
        case .app, .appTests:
            return Self.appFilesToUploadQuery
        case .fileProviderExtension:
            return Self.fileProviderFilesToUploadQuery
        case .actionExtension:
            // not supported in actionExtension
            return nil
        case .shareExtension:
            // not supported in shareExtension
            return nil
        }
    }

    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        Log.uploadQueue("waitForCompletion")
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            Log.uploadQueue("🎉 AllOperationsAreFinished")
            completionHandler()
        }
    }

    public func getOperation(forUploadFileId uploadFileId: String) -> UploadOperationable? {
        Log.uploadQueue("getOperation ufid:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return nil
        }

        let operation = operation(uploadFileId: uploadFileId)
        return operation
    }

    public func rebuildUploadQueueFromObjectsInRealm(_ caller: StaticString = #function) {
        Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm caller:\(caller)")
        serialQueue.sync {
            // Clean cache if necessary before we try to restart the uploads.
            @InjectService var freeSpaceService: FreeSpaceService
            freeSpaceService.cleanCacheIfAlmostFull()

            guard let uploadFileQuery else {
                Log.uploadQueue("\(#function) disabled in \(appContextService.context.rawValue)", level: .error)
                return
            }

            let uploadingFiles = uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
                return lazyCollection.filter(uploadFileQuery)
                    .sorted(byKeyPath: "taskCreationDate")
            }
            let uploadingFileIds = Array(uploadingFiles.map(\.id))
            Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm uploads to restart:\(uploadingFileIds.count)")

            let batches = uploadingFileIds.chunks(ofCount: 100)
            Log.uploadQueue("batched count:\(batches.count)")
            for batch in batches {
                Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm in batch")
                let batchArray = Array(batch)
                let matchedFrozenFiles = uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
                    lazyCollection.filter("id IN %@", batchArray).freezeIfNeeded()
                }
                for file in matchedFrozenFiles {
                    addToQueueIfNecessary(uploadFile: file)
                }
                self.resumeAllOperations()
            }

            Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm exit")
        }
    }

    @discardableResult
    public func saveToRealm(_ uploadFile: UploadFile,
                            itemIdentifier: NSFileProviderItemIdentifier? = nil,
                            addToQueue: Bool = true) -> UploadOperationable? {
        let expiringActivity = ExpiringActivity()
        expiringActivity.start()
        defer {
            expiringActivity.endAll()
        }

        Log.uploadQueue("saveToRealm addToQueue:\(addToQueue) ufid:\(uploadFile.id)")

        assert(!uploadFile.isManagedByRealm, "we expect the file to be outside of realm at the moment")

        // Save drive and directory
        UserDefaults.shared.lastSelectedUser = uploadFile.userId
        UserDefaults.shared.lastSelectedDrive = uploadFile.driveId
        UserDefaults.shared.lastSelectedDirectory = uploadFile.parentDirectoryId

        uploadFile.name = uploadFile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if uploadFile.error != nil {
            uploadFile.error = nil
        }

        // Keep a detached file for processing it later
        let detachedFile = uploadFile.detached()
        try? uploadsDatabase.writeTransaction { writableRealm in
            Log.uploadQueue("save ufid:\(uploadFile.id)")
            writableRealm.add(uploadFile, update: .modified)
            Log.uploadQueue("did save ufid:\(uploadFile.id)")
        }

        guard addToQueue else {
            return nil
        }

        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("addToQueue disabled in ShareExtension", level: .error)
            return nil
        }

        // Process adding a detached file to the uploadQueue
        let uploadOperation = self.addToQueue(uploadFile: detachedFile, itemIdentifier: itemIdentifier)

        return uploadOperation
    }

    public func suspendAllOperations() {
        Log.uploadQueue("suspendAllOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        forceSuspendQueue = true
        operationQueue.isSuspended = true
    }

    public func resumeAllOperations() {
        Log.uploadQueue("resumeAllOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        forceSuspendQueue = false
        operationQueue.isSuspended = shouldSuspendQueue
    }

    public func rescheduleRunningOperations() {
        Log.uploadQueue("rescheduleRunningOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        reschedule(operations: operationQueue.operations.filter(\.isExecuting))
    }

    private func reschedule(operations: [Operation]) {
        for operation in operations {
            guard let uploadOperation = operation as? UploadOperation else {
                continue
            }

            // Mark the operation as rescheduled
            uploadOperation.backgroundActivityExpiring()
        }
    }

    public func cancelRunningOperations() {
        Log.uploadQueue("cancelRunningOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        operationQueue.operations.filter(\.isExecuting).forEach { $0.cancel() }
    }

    @discardableResult
    public func cancel(uploadFileId: String) -> Bool {
        Log.uploadQueue("cancel uploadFileId:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return false
        }

        var found = false
        concurrentQueue.sync {
            guard let toDeleteLive = uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId) else {
                return
            }

            found = true
            let fileToDelete = toDeleteLive.detached()
            self.cancel(uploadFile: fileToDelete)
        }

        return found
    }

    public func cancel(uploadFile: UploadFile) {
        Log.uploadQueue("cancel UploadFile ufid:\(uploadFile.id)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        uploadFile.cleanSourceFileIfNeeded()

        let uploadFileId = uploadFile.id
        let userId = uploadFile.userId
        let parentId = uploadFile.parentDirectoryId
        let driveId = uploadFile.driveId

        concurrentQueue.async {
            if let operation = self.keyedUploadOperations.getObject(forKey: uploadFileId) {
                Log.uploadQueue("operation to cancel:\(operation)")
                Task {
                    await operation.cleanUploadFileSession()
                    operation.cancel()
                }
            }
            self.keyedUploadOperations.removeObject(forKey: uploadFileId)

            try? self.uploadsDatabase.writeTransaction { writableRealm in
                if let toDelete = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
                   !toDelete.isInvalidated {
                    Log.uploadQueue("find UploadFile to delete :\(uploadFileId)")
                    let publishedToDelete = UploadFile(value: toDelete)
                    publishedToDelete.error = .taskCancelled
                    writableRealm.delete(toDelete)

                    Log.uploadQueue("publishFileUploaded ufid:\(uploadFileId)")
                    self.publishFileUploaded(result: UploadCompletionResult(uploadFile: publishedToDelete, driveFile: nil))
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
                } else {
                    Log.uploadQueue("could not find file to cancel:\(uploadFileId)", level: .error)
                }
            }
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        Log.uploadQueue("cancelAllOperations parentId:\(parentId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        concurrentQueue.async {
            Log.uploadQueue("suspend queue")
            self.suspendAllOperations()

            let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                        userId: userId,
                                                        driveId: driveId)

            let uploadingFilesIds = Array(uploadingFiles.map(\.id))
            Log.uploadQueue("cancelAllOperations count:\(uploadingFiles.count) parentId:\(parentId)")
            Log.uploadQueue("cancelAllOperations IDS count:\(uploadingFilesIds.count) parentId:\(parentId)")

            try? self.uploadsDatabase.writeTransaction { writableRealm in
                // Delete all the linked UploadFiles from Realm. This is fast.
                Log.uploadQueue("delete all matching files count:\(uploadingFiles.count) parentId:\(parentId)")
                let objectsToDelete = writableRealm.objects(UploadFile.self).filter("id IN %@", uploadingFilesIds)

                writableRealm.delete(objectsToDelete)
                Log.uploadQueue("Done deleting all matching files for parentId:\(parentId)")
            }

            // Remove in batches from upload queue. This may take a while.
            let batches = uploadingFilesIds.chunks(ofCount: 100)
            for fileIds in batches {
                autoreleasepool {
                    for id in fileIds {
                        // Cancel operation if any
                        if let operation = self.keyedUploadOperations.getObject(forKey: id) {
                            operation.cancel()
                        }
                        self.keyedUploadOperations.removeObject(forKey: id)
                    }
                }
            }

            self.publishUploadCount(withParent: parentId,
                                    userId: userId,
                                    driveId: driveId)

            Log.uploadQueue("cancelAllOperations finished")
            self.resumeAllOperations()
        }
    }

    public func cleanNetworkAndLocalErrorsForAllOperations() {
        Log.uploadQueue("cleanErrorsForAllOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        concurrentQueue.sync {
            try? self.uploadsDatabase.writeTransaction { writableRealm in
                // UploadFile with an error, Or no more retry.
                let ownedByFileProvider = NSNumber(value: self.appContextService.context == .fileProviderExtension)
                let failedUploadFiles = writableRealm.objects(UploadFile.self)
                    .filter("_error != nil OR maxRetryCount <= 0 AND ownedByFileProvider == %@", ownedByFileProvider)
                    .filter { file in
                        guard let error = file.error else {
                            return false
                        }

                        return error.type != .serverError
                    }
                Log.uploadQueue("will clean errors for uploads:\(failedUploadFiles.count)")
                for file in failedUploadFiles {
                    file.clearErrorsForRetry()
                }

                Log.uploadQueue("cleaned errors on \(failedUploadFiles.count) files")
            }
        }
    }

    public func retry(_ uploadFileId: String) {
        Log.uploadQueue("retry ufid:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        concurrentQueue.async {
            try? self.uploadsDatabase.writeTransaction { writableRealm in
                guard let file = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
                      !file.isInvalidated else {
                    Log.uploadQueue("file invalidated in\(#function) line:\(#line) ufid:\(uploadFileId)")
                    return
                }

                // Remove operation from tracking
                if let operation = self.operation(uploadFileId: uploadFileId) {
                    operation.cancel()
                    self.keyedUploadOperations.removeObject(forKey: uploadFileId)
                }

                // Clean error in base
                file.clearErrorsForRetry()
            }

            // re-enqueue UploadOperation
            defer {
                self.resumeAllOperations()
            }

            guard let frozenFile = self.uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId)?
                .freeze() else {
                return
            }

            self.addToQueue(uploadFile: frozenFile)
        }
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        Log.uploadQueue("retryAllOperations parentId:\(parentId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        concurrentQueue.async {
            let failedFileIds = self.getFailedFileIds(parentId: parentId, userId: userId, driveId: driveId)
            let batches = failedFileIds.chunks(ofCount: 100)
            Log.uploadQueue("batches:\(batches.count)")

            self.resumeAllOperations()

            for batch in batches {
                Log.uploadQueue("in batch")
                // Cancel Operation if any and reset errors
                self.cancelAnyInBatch(batch)

                // Second transaction to enqueue the UploadFile to the OperationQueue
                self.enqueueAnyInBatch(batch)
            }
        }
    }

    // MARK: - Private methods

    private func getFailedFileIds(parentId: Int, userId: Int, driveId: Int) -> [String] {
        Log.uploadQueue("retryAllOperations in dispatchQueue parentId:\(parentId)")
        let ownedByFileProvider = NSNumber(value: appContextService.context == .fileProviderExtension)
        let uploadingFiles = getUploadingFiles(withParent: parentId,
                                               userId: userId,
                                               driveId: driveId)

        Log.uploadQueue("uploading:\(uploadingFiles.count)")
        let failedUploadFiles = uploadingFiles
            .filter("_error != nil OR maxRetryCount <= 0 AND ownedByFileProvider == %@", ownedByFileProvider)

        let failedFileIds = Array(failedUploadFiles.map(\.id))
        Log.uploadQueue("retying:\(failedFileIds.count)")

        return failedFileIds
    }

    private func cancelAnyInBatch(_ batch: ArraySlice<String>) {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        try? uploadsDatabase.writeTransaction { writableRealm in
            for uploadFileId in batch {
                // Cancel operation if any
                if let operation = self.operation(uploadFileId: uploadFileId) {
                    operation.cancel()
                    self.keyedUploadOperations.removeObject(forKey: uploadFileId)
                }

                // Clean errors in db file
                guard let file = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
                      !file.isInvalidated else {
                    Log.uploadQueue("file invalidated ufid:\(uploadFileId) at\(#line)")
                    continue
                }

                file.clearErrorsForRetry()
            }
        }
    }

    private func enqueueAnyInBatch(_ batch: ArraySlice<String>) {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        for uploadFileId in batch {
            guard let file = uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId) else {
                Log.uploadQueue("file invalidated ufid:\(uploadFileId) at\(#line)")
                continue
            }

            addToQueueIfNecessary(uploadFile: file)
        }
    }

    private func operation(uploadFileId: String) -> UploadOperationable? {
        Log.uploadQueue("operation fileId:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return nil
        }

        guard let operation = keyedUploadOperations.getObject(forKey: uploadFileId),
              !operation.isCancelled,
              !operation.isFinished else {
            return nil
        }
        return operation
    }

    private func addToQueueIfNecessary(uploadFile: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        guard !uploadFile.isInvalidated else {
            return
        }

        Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm ufid:\(uploadFile.id)")
        guard operation(uploadFileId: uploadFile.id) != nil else {
            Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm ADD ufid:\(uploadFile.id)")
            addToQueue(uploadFile: uploadFile, itemIdentifier: nil)
            return
        }

        Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm NOOP ufid:\(uploadFile.id)")
    }

    @discardableResult
    private func addToQueue(uploadFile: UploadFile,
                            itemIdentifier: NSFileProviderItemIdentifier? = nil) -> UploadOperation? {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return nil
        }

        guard !uploadFile.isInvalidated,
              uploadFile.maxRetryCount > 0,
              keyedUploadOperations.getObject(forKey: uploadFile.id) == nil else {
            Log.uploadQueue("invalid file in \(#function)", level: .error)
            return nil
        }

        let uploadFileId = uploadFile.id
        let parentId = uploadFile.parentDirectoryId
        let userId = uploadFile.userId
        let driveId = uploadFile.driveId
        let priority = uploadFile.priority
        OperationQueueHelper.disableIdleTimer(true)

        let operation = UploadOperation(uploadFileId: uploadFileId, urlSession: bestSession)
        operation.queuePriority = priority
        operation.completionBlock = { [weak self] in
            guard let self else { return }
            Log.uploadQueue("operation.completionBlock for operation:\(operation) ufid:\(uploadFileId)")
            keyedUploadOperations.removeObject(forKey: uploadFileId)
            if let error = operation.result.uploadFile?.error,
               error == .taskRescheduled || error == .taskCancelled {
                Log.uploadQueue("skipping task")
                return
            }

            publishFileUploaded(result: operation.result)
            publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
            OperationQueueHelper.disableIdleTimer(false, hasOperationsInQueue: !keyedUploadOperations.isEmpty)
        }

        Log.uploadQueue("add operation :\(operation) ufid:\(uploadFileId)")
        operationQueue.addOperation(operation as Operation)

        keyedUploadOperations.setObject(operation, key: uploadFileId)
        publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)

        return operation
    }
}
