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
import InfomaniakCoreDB
import InfomaniakDI

public enum UploadServiceBackgroundIdentifier {
    public static let base = ".backgroundsession.upload"
    public static let app: String = (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + base
}

public final class UploadService {
    @InjectService(customTypeIdentifier: UploadQueueID.global) var globalUploadQueue: UploadQueueable
    @InjectService(customTypeIdentifier: UploadQueueID.photo) var photoUploadQueue: UploadQueueable

    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var appContextService: AppContextServiceable

    private let serialTransactionQueue = DispatchQueue(
        label: "com.infomaniak.drive.upload-service.rebuild-uploads",
        qos: .default,
        autoreleaseFrequency: .workItem
    )

    let serialEventQueue: DispatchQueue = {
        @InjectService var appContextService: AppContextServiceable
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = appContextService.isExtension ? .workItem : .inherit

        return DispatchQueue(
            label: "com.infomaniak.drive.upload-service.event",
            qos: .default,
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
        allQueues.reduce(0) { $0 + $1.operationCount }
    }

    public var pausedNotificationSent = false

    public init() {
        rebuildUploadQueue()
        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            self?.updateQueueSuspension()
        }
    }
}

extension UploadService: UploadServiceable {
    static let appFilesToUploadQuery = "uploadDate = nil AND maxRetryCount > 0 AND ownedByFileProvider == false"

    static let fileProviderFilesToUploadQuery = "uploadDate = nil AND maxRetryCount > 0 AND ownedByFileProvider == true"

    private var uploadFileQuery: String? {
        switch appContextService.context {
        case .app, .appTests:
            return Self.appFilesToUploadQuery
        case .fileProviderExtension:
            return Self.fileProviderFilesToUploadQuery
        case .actionExtension, .shareExtension:
            return nil
        }
    }

    public var isSuspended: Bool {
        allQueues.allSatisfy(\.isSuspended)
    }

    public func blockingRebuildUploadQueue() {
        serialTransactionQueue.sync {
            self.rebuildUploadQueueFromObjectsInRealm()
        }
    }

    public func rebuildUploadQueue() {
        serialTransactionQueue.async {
            self.rebuildUploadQueueFromObjectsInRealm()
        }
    }

    private func rebuildUploadQueueFromObjectsInRealm() {
        Log.uploadQueue("rebuildUploadQueue")
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
                let uploadQueue = uploadQueue(for: file)
                uploadQueue.addToQueueIfNecessary(uploadFile: file, itemIdentifier: nil)
            }
            resumeAllOperations()
        }

        Log.uploadQueue("rebuildUploadQueueFromObjectsInRealm exit")
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

        serialTransactionQueue.async {
            guard let frozenFile = self.uploadsDatabase.fetchObject(ofType: UploadFile.self, forPrimaryKey: uploadFileId)?
                .freeze() else {
                return
            }

            let specificQueue = self.uploadQueue(for: frozenFile)

            try? self.uploadsDatabase.writeTransaction { writableRealm in
                guard let file = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
                      !file.isInvalidated else {
                    Log.uploadQueue("file invalidated in\(#function) line:\(#line) ufid:\(uploadFileId)")
                    return
                }

                specificQueue.cancel(uploadFileId: uploadFileId)

                file.clearErrorsForRetry()
            }

            specificQueue.addToQueue(uploadFile: frozenFile, itemIdentifier: nil)
            self.resumeAllOperations()
        }
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        Log.uploadQueue("retryAllOperations parentId:\(parentId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        serialTransactionQueue.async {
            let failedFileIds = self.getFailedFileIds(parentId: parentId, userId: userId, driveId: driveId)
            let batches = failedFileIds.chunks(ofCount: 100)
            Log.uploadQueue("batches:\(batches.count)")

            self.resumeAllOperations()

            for batch in batches {
                self.cancelAnyInBatch(batch)
                self.enqueueAnyInBatch(batch)
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
                guard let file = writableRealm.object(ofType: UploadFile.self, forPrimaryKey: uploadFileId),
                      !file.isInvalidated else {
                    Log.uploadQueue("file invalidated ufid:\(uploadFileId) at\(#line)")
                    continue
                }
                let uploadQueue = uploadQueue(for: file)
                uploadQueue.cancel(uploadFileId: uploadFileId)
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

            let uploadQueue = uploadQueue(for: file)
            uploadQueue.addToQueueIfNecessary(uploadFile: file, itemIdentifier: nil)
        }
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        Log.uploadQueue("cancelAllOperations parentId:\(parentId)")
        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("\(#function) disabled in ShareExtension", level: .error)
            return
        }

        serialTransactionQueue.async {
            self.suspendAllOperations()
            defer {
                self.resumeAllOperations()
                Log.uploadQueue("cancelAllOperations finished")
            }

            let uploadingFiles = self.getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId)
            let allUploadingFilesIds = Array(uploadingFiles.map(\.id))
            let photoSyncUploadingFilesIds: [String] = uploadingFiles.compactMap { uploadFile in
                guard uploadFile.isPhotoSyncUpload else { return nil }
                return uploadFile.id
            }
            let globalUploadingFilesIds: [String] = uploadingFiles.compactMap { uploadFile in
                guard !uploadFile.isPhotoSyncUpload else { return nil }
                return uploadFile.id
            }

            assert(
                photoSyncUploadingFilesIds.count + globalUploadingFilesIds.count == uploadingFiles.count,
                "count of IDs should match"
            )

            Log.uploadQueue("cancelAllOperations IDS count:\(allUploadingFilesIds.count) parentId:\(parentId)")

            try? self.uploadsDatabase.writeTransaction { writableRealm in
                // Delete all the linked UploadFiles from Realm. This is fast.
                Log.uploadQueue("delete all matching files count:\(uploadingFiles.count) parentId:\(parentId)")
                let objectsToDelete = writableRealm.objects(UploadFile.self).filter("id IN %@", allUploadingFilesIds)

                writableRealm.delete(objectsToDelete)
                Log.uploadQueue("Done deleting all matching files for parentId:\(parentId)")
            }

            self.globalUploadQueue.cancelAllOperations(uploadingFilesIds: globalUploadingFilesIds)
            self.photoUploadQueue.cancelAllOperations(uploadingFilesIds: photoSyncUploadingFilesIds)

            self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId)
        }
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
        let uploadQueue = uploadQueue(for: frozenFileToDelete)
        uploadQueue.cancel(uploadFileId: frozenFileToDelete.id)

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

    public func updateQueueSuspension() {
        allQueues.forEach { $0.updateQueueSuspension() }
    }

    private func uploadQueue(for uploadFile: UploadFile) -> UploadQueueable {
        if uploadFile.isPhotoSyncUpload {
            return photoUploadQueue
        } else {
            return globalUploadQueue
        }
    }
}
