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

// import RealmSwift
import InfomaniakDI

public enum UploadServiceBackgroundIdentifier {
    public static let base = ".backgroundsession.upload"
    public static let app: String = (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + base
}

public final class UploadService {
    @LazyInjectService(customTypeIdentifier: UploadQueueID.global) var globalUploadQueue: UploadQueueable
    @LazyInjectService(customTypeIdentifier: UploadQueueID.photo) var photoUploadQueue: UploadQueueable

    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable
//    @LazyInjectService var accountManager: AccountManageable
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
            self.rebuildUploadQueueFromObjectsInRealm()
        }
    }
}

extension UploadService: UploadServiceable {
    public var isSuspended: Bool {
        return globalUploadQueue.isSuspended && globalUploadQueue.isSuspended
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
                    // TODO: Do it in this object and forward objects to specific queues
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
        globalUploadQueue.retry(uploadFileId)
        photoUploadQueue.retry(uploadFileId)
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        globalUploadQueue.retryAllOperations(withParent: parentId, userId: userId, driveId: driveId)
        photoUploadQueue.retryAllOperations(withParent: parentId, userId: userId, driveId: driveId)
    }

    public func cancelAllOperations(withParent parentId: Int, userId: Int, driveId: Int) {
        globalUploadQueue.cancelAllOperations(withParent: parentId, userId: userId, driveId: driveId)
        photoUploadQueue.cancelAllOperations(withParent: parentId, userId: userId, driveId: driveId)
    }

    public func rescheduleRunningOperations() {
        allQueues.forEach { $0.rescheduleRunningOperations() }
    }

    public func cancelRunningOperations() {
        allQueues.forEach { $0.cancelRunningOperations() }
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

        // TODO: Select correct upload queue
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
