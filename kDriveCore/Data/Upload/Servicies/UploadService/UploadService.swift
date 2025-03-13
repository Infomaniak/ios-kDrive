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
import InfomaniakCoreDB
import InfomaniakDI

public enum UploadServiceBackgroundIdentifier {
    public static let base = ".backgroundsession.upload"
    public static let app: String = (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + base
}

public final class UploadService {
    @LazyInjectService(customTypeIdentifier: UploadQueueID.global) var globalUploadQueue: UploadQueueable
    @LazyInjectService(customTypeIdentifier: UploadQueueID.photo) var photoUploadQueue: UploadQueueable
    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var appContextService: AppContextServiceable

    let serialQueue: DispatchQueue = {
        @LazyInjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(
            label: "com.infomaniak.drive.upload-service",
            qos: .userInitiated,
            autoreleaseFrequency: autoreleaseFrequency
        )
    }()

    lazy var allQueues = [globalUploadQueue, photoUploadQueue]

    var fileUploadedCount = 0
    var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    public var operationCount: Int {
        globalUploadQueue.operationCount + photoUploadQueue.operationCount
    }

    public var pausedNotificationSent = false

    public init() {
        Task {
            rebuildUploadQueueFromObjectsInRealm()
        }
    }
}

extension UploadService: UploadServiceable {
    public var isSuspended: Bool {
        return globalUploadQueue.isSuspended && photoUploadQueue.isSuspended
    }

    public func rebuildUploadQueueFromObjectsInRealm() {
        Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm")
        serialQueue.sync {
            // Clean cache if necessary before we try to restart the uploads.
            @InjectService var freeSpaceService: FreeSpaceService
            freeSpaceService.cleanCacheIfAlmostFull()

            guard let uploadFileQuery = globalUploadQueue.uploadFileQuery else {
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
                    globalUploadQueue.addToQueueIfNecessary(uploadFile: file, itemIdentifier: nil)
                }
                resumeAllOperations()
            }

            Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm exit")
        }
    }

    public func suspendAllOperations() {
        allQueues.forEach { $0.suspendAllOperations() }
    }

    public func resumeAllOperations() {
        allQueues.forEach { $0.resumeAllOperations() }
    }

    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        globalUploadQueue.waitForCompletion {
            self.photoUploadQueue.waitForCompletion {
                completionHandler()
            }
        }
    }

    public func retry(_ uploadFileId: String) {
        Log.uploadQueue("retry ufid:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        Task {
            try? self.uploadsDatabase.writeTransaction { writableRealm in
                guard let file = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
                      !file.isInvalidated else {
                    Log.uploadQueue("file invalidated in\(#function) line:\(#line) ufid:\(uploadFileId)")
                    return
                }

                // Remove operation from tracking
                globalUploadQueue.cancel(uploadFileId: uploadFileId)

                // Clean error in base
                file.clearErrorsForRetry()
            }

            // re-enqueue UploadOperation
            defer {
                resumeAllOperations()
            }

            guard let frozenFile = self.uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId)?
                .freeze() else {
                return
            }

            globalUploadQueue.addToQueue(uploadFile: frozenFile, itemIdentifier: nil)
        }
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        Log.uploadQueue("retryAllOperations parentId:\(parentId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        Task {
            let failedFileIds = getFailedFileIds(parentId: parentId, userId: userId, driveId: driveId)
            let batches = failedFileIds.chunks(ofCount: 100)
            Log.uploadQueue("batches:\(batches.count)")

            resumeAllOperations()

            for batch in batches {
                // Cancel Operation if any and reset errors
                cancelAnyInBatch(batch)

                // Second transaction to enqueue the UploadFile to the OperationQueue
                enqueueAnyInBatch(batch)
            }
        }
    }

    private func getFailedFileIds(parentId: Int, userId: Int, driveId: Int) -> [String] {
        Log.uploadQueue("retryAllOperations in dispatchQueue parentId:\(parentId)")
        let ownedByFileProvider = NSNumber(value: appContextService.context == .fileProviderExtension)
        let uploadingFiles = getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId)

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
                globalUploadQueue.cancel(uploadFileId: uploadFileId)

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

            globalUploadQueue.addToQueueIfNecessary(uploadFile: file, itemIdentifier: nil)
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        Log.uploadQueue("cancelAllOperations parentId:\(parentId)")
        defer {
            Log.uploadQueue("cancelAllOperations finished")
        }

        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        suspendAllOperations()

        let uploadingFiles = getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId)
        let uploadingFilesIds = Array(uploadingFiles.map(\.id))
        Log.uploadQueue("cancelAllOperations IDS count:\(uploadingFilesIds.count) parentId:\(parentId)")

        try? uploadsDatabase.writeTransaction { writableRealm in
            // Delete all the linked UploadFiles from Realm. This is fast.
            Log.uploadQueue("delete all matching files count:\(uploadingFiles.count) parentId:\(parentId)")
            let objectsToDelete = writableRealm.objects(UploadFile.self).filter("id IN %@", uploadingFilesIds)

            writableRealm.delete(objectsToDelete)
            Log.uploadQueue("Done deleting all matching files for parentId:\(parentId)")
        }

        globalUploadQueue.cancelAllOperations(uploadingFilesIds: uploadingFilesIds)
        photoUploadQueue.cancelAllOperations(uploadingFilesIds: uploadingFilesIds)

        publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
        resumeAllOperations()
    }

    public func rescheduleRunningOperations() {
        allQueues.forEach { $0.rescheduleRunningOperations() }
    }

    @discardableResult
    public func cancel(uploadFileId: String) -> Bool {
        Log.uploadQueue("cancel uploadFileId:\(uploadFileId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return false
        }

        guard let toDeleteLive = uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId) else {
            return false
        }

        let frozenFileToDelete = toDeleteLive.freeze()
        frozenFileToDelete.cleanSourceFileIfNeeded()

        globalUploadQueue.cancel(uploadFileId: frozenFileToDelete.id)

        try? uploadsDatabase.writeTransaction { writableRealm in
            if let toDelete = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
               !toDelete.isInvalidated {
                Log.uploadQueue("find UploadFile to delete :\(uploadFileId)")
                let publishedToDelete = UploadFile(value: toDelete)
                publishedToDelete.error = .taskCancelled
                writableRealm.delete(toDelete)

                Log.uploadQueue("publishFileUploaded ufid:\(uploadFileId)")
                self.publishFileUploaded(result: UploadCompletionResult(
                    uploadFile: publishedToDelete,
                    driveFile: nil
                ))
                self.publishUploadCount(
                    withParent: frozenFileToDelete.parentDirectoryId,
                    userId: frozenFileToDelete.userId,
                    driveId: frozenFileToDelete.driveId
                )
            } else {
                Log.uploadQueue("could not find file to cancel:\(uploadFileId)", level: .error)
            }
        }
        return true
    }

    public func cleanNetworkAndLocalErrorsForAllOperations() {
        Log.uploadQueue("cleanErrorsForAllOperations")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        try? uploadsDatabase.writeTransaction { writableRealm in
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
