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
    public var operationCount: Int {
        operationQueue.operationCount
    }

    public var isSuspended: Bool {
        operationQueue.isSuspended
    }

    public var isActive: Bool {
        operationQueue.operationCount > 0 && !operationQueue.isSuspended
    }

    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        Log.uploadQueue("\(self) waitForCompletion")
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            Log.uploadQueue("\(self) 🎉 AllOperationsAreFinished")
            completionHandler()
        }
    }

    public func getOperation(forUploadFileId uploadFileId: String) -> UploadOperationable? {
        Log.uploadQueue("\(self) getOperation ufid:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return nil
        }

        let operation = operation(uploadFileId: uploadFileId)
        return operation
    }

    public func suspendAllOperations() {
        Log.uploadQueue("\(self) suspendAllOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        forceSuspendQueue = true
        operationQueue.isSuspended = true
    }

    public func resumeAllOperations() {
        Log.uploadQueue("\(self) resumeAllOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return
        }

        forceSuspendQueue = false
        operationQueue.isSuspended = shouldSuspendQueue
    }

    public func rescheduleRunningOperations() {
        Log.uploadQueue("\(self) rescheduleRunningOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
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

    public func cancel(uploadFileId: String) {
        Log.uploadQueue("\(self) cancel UploadFile ufid:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return
        }

        if let operation = keyedUploadOperations.getObject(forKey: uploadFileId) {
            Log.uploadQueue("\(self) operation to cancel:\(operation)")
            Task {
                await operation.cleanUploadFileSession()
                operation.cancel()
            }
        }
        keyedUploadOperations.removeObject(forKey: uploadFileId)
    }

    public func cancelAllOperations(uploadingFilesIds: [String]) {
        Log.uploadQueue("\(self) cancelAllOperations queue:\(type(of: self))")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return
        }

        Log.uploadQueue("\(self) cancelAllOperations IDS count:\(uploadingFilesIds.count) queue:\(type(of: self))")

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
    }

    public func cancelAllOperations() {
        operationQueue.cancelAllOperations()
        keyedUploadOperations.removeAll()
    }

    private func operation(uploadFileId: String) -> UploadOperationable? {
        Log.uploadQueue("\(self) operation fileId:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return nil
        }

        guard let operation = keyedUploadOperations.getObject(forKey: uploadFileId),
              !operation.isCancelled,
              !operation.isFinished else {
            return nil
        }
        return operation
    }

    public func addToQueueIfNecessary(uploadFile: UploadFile, itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return
        }

        guard !uploadFile.isInvalidated else {
            return
        }

        Log.uploadQueue("\(self) addToQueueIfNecessary ufid:\(uploadFile.id)")
        guard operation(uploadFileId: uploadFile.id) != nil else {
            Log.uploadQueue("\(self) addToQueueIfNecessary ADD ufid:\(uploadFile.id)")
            addToQueue(uploadFile: uploadFile, itemIdentifier: nil)
            return
        }

        Log.uploadQueue("\(self) addToQueueIfNecessary NOOP ufid:\(uploadFile.id)")
    }

    @discardableResult
    public func addToQueue(uploadFile: UploadFile,
                           itemIdentifier: NSFileProviderItemIdentifier? = nil) -> UploadOperation? {
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(self) \(#function) disabled in ShareExtension", level: .error)
            return nil
        }

        guard !uploadFile.isInvalidated,
              uploadFile.maxRetryCount > 0,
              keyedUploadOperations.getObject(forKey: uploadFile.id) == nil else {
            Log.uploadQueue("\(self) invalid file in \(#function)", level: .error)
            return nil
        }

        let uploadFileId = uploadFile.id
        let parentId = uploadFile.parentDirectoryId
        let userId = uploadFile.userId
        let driveId = uploadFile.driveId
        let priority = uploadFile.priority
        OperationQueueHelper.disableIdleTimer(true)

        let operation = UploadOperation(uploadFileId: uploadFileId, urlSession: foregroundSession)
        operation.queuePriority = priority
        operation.completionBlock = { [weak self] in
            guard let self else { return }
            Log.uploadQueue("\(self) operation.completionBlock for operation:\(operation) ufid:\(uploadFileId)")
            keyedUploadOperations.removeObject(forKey: uploadFileId)
            if let error = operation.result.uploadFile?.error, Self.silentErrors.contains(error) {
                Log.uploadQueue("\(self) skipping task")
                return
            }

            uploadPublisher.publishFileUploaded(result: operation.result)
            uploadPublisher.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
            OperationQueueHelper.disableIdleTimer(false)
        }

        Log.uploadQueue("\(self) add operation :\(operation) ufid:\(uploadFileId)")
        operationQueue.addOperation(operation as Operation)

        keyedUploadOperations.setObject(operation, key: uploadFileId)
        uploadPublisher.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)

        return operation
    }

    public func updateQueueSuspension() {
        let suspended = (shouldSuspendQueue || forceSuspendQueue)
        operationQueue.isSuspended = suspended
        Log.uploadQueue("\(self) update isSuspended to :\(suspended)")
    }
}
