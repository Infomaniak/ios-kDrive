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
    
    func addToQueueFromRealm()

    func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier?) -> UploadOperationable?

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
        UploadQueueLog("waitForCompletion")
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            completionHandler()
        }
    }

    public func getOperation(forFileId fileId: String) -> UploadOperationable? {
        UploadQueueLog("getOperation fid:\(fileId)")
        var operation: UploadOperationable? = nil
        dispatchQueue.sync {
            operation = self.operation(fileId: fileId)
        }
        return operation
    }
    
    public func addToQueueFromRealm() {
        UploadQueueLog("addToQueueFromRealm")
        foregroundSession.getTasksWithCompletionHandler { _, uploadTasks, _ in
            self.dispatchQueue.async {
                let uploadingFiles = self.realm.objects(UploadFile.self)
                    .filter("uploadDate = nil AND maxRetryCount > 0")
                    .sorted(byKeyPath: "taskCreationDate")
                UploadQueueLog("addToQueueFromRealm uploads to restart:\(uploadingFiles.count)")
                autoreleasepool {
                    uploadingFiles.forEach { uploadFile in
                        UploadQueueLog("addToQueueFromRealm fid:\(uploadFile.id)")
                        
                        // Get the operation and try to restart it OR add it
                        guard let operation = self.operation(fileId: uploadFile.id) else {
                            self.dispatchQueue.async {
                                self.addToQueue(file: uploadFile, itemIdentifier: nil, using: self.realm)
                            }
                            return
                        }
                        
                        // Check if operation is running and needs to be restarted ?
                        operation.retryIfNeeded()
                    }
                }
            }
        }
    }

    public func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil) -> UploadOperationable? {
        UploadQueueLog("addToQueue fid:\(file.id)")
        var uploadOperation: UploadOperation? = nil
        dispatchQueue.sync {
            uploadOperation = self.addToQueue(file: file, itemIdentifier: itemIdentifier, using: self.realm)
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

    public func cancelAllOperations() {
        UploadQueueLog("cancelAllOperations")
        operationQueue.cancelAllOperations()
    }

    public func cancelRunningOperations() {
        UploadQueueLog("cancelRunningOperations")
        operationQueue.operations.filter(\.isExecuting).forEach { ($0 as? AsynchronousOperation)?.finish() }
    }

    public func cancel(_ file: UploadFile) {
        UploadQueueLog("cancel fid:\(file.id)")
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
                (operation as? AsynchronousOperation)?.finish()
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        UploadQueueLog("cancelAllOperations parentId:\(parentId)")
        dispatchQueue.async {
            self.suspendAllOperations()
            let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                        userId: userId,
                                                        driveId: driveId,
                                                        using: self.realm)
            uploadingFiles.forEach { file in
                if !file.isInvalidated,
                   let operation = self.operationsInQueue[file.id] as? AsynchronousOperation {
                    operation.finish()
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
        UploadQueueLog("retry fid:\(file.id)")
        let safeFile = ThreadSafeReference(to: file)
        dispatchQueue.async {
            guard let file = self.realm.resolve(safeFile), !file.isInvalidated else { return }
            try? self.realm.safeWrite {
                file.error = nil
                file.maxRetryCount = UploadFile.defaultMaxRetryCount
            }
            self.addToQueue(file: file, using: self.realm)
        }
    }

    public func retryAllOperations(withParent parentId: Int,
                                   userId: Int,
                                   driveId: Int) {
        UploadQueueLog("retryAllOperations parentId:\(parentId)")
        dispatchQueue.async {
            let uploadingFiles = self.getUploadingFiles(withParent: parentId,
                                                        userId: userId,
                                                        driveId: driveId,
                                                        using: self.realm)
            let failedUploadFiles = uploadingFiles.filter("_error != nil")
            try? self.realm.safeWrite {
                failedUploadFiles.forEach { file in
                    file.error = nil
                    file.maxRetryCount = UploadFile.defaultMaxRetryCount
                }
            }
            failedUploadFiles.forEach {
                self.addToQueue(file: $0, using: self.realm)
            }
            
            self.addToQueueFromRealm()
        }
    }

    // MARK: - Private methods
    
    private func operation(fileId: String) -> UploadOperationable? {
        UploadQueueLog("operation fileId:\(fileId)")
        guard let operation = operationsInQueue[fileId],
              operation.isCancelled == false else {
            return nil
        }
        return operation
    }

    @discardableResult
    private func addToQueue(file: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil, using realm: Realm) -> UploadOperation? {
        guard !file.isInvalidated && operationsInQueue[file.id] == nil && file.maxRetryCount > 0 else {
            UploadQueueLog("addToQueue isInvalidated:\(file.isInvalidated) operationsInQueue:\(operationsInQueue[file.id] == nil) maxRetryCount:\(file.maxRetryCount) fid:\(file.id)", level: .error)
            return nil
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
                guard operation.result.uploadFile?.error != .taskRescheduled else {
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
