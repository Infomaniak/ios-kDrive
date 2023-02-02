/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import InfomaniakDI
import RealmSwift
import Sentry

public class UploadQueue {

    @InjectService var accountManager: AccountManageable

//    public static let instance = UploadQueue() still needed ?
    public static let backgroundBaseIdentifier = ".backgroundsession.upload"
    public static var backgroundIdentifier: String {
        return (Bundle.main.bundleIdentifier ?? "com.infomaniak.drive") + backgroundBaseIdentifier
    }

    public var pausedNotificationSent = false

    private let dispatchQueue = DispatchQueue(label: "com.infomaniak.drive.upload-sync", autoreleaseFrequency: .workItem)

    private(set) var operationsInQueue: [String: UploadOperation] = [:]
    private(set) lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kDrive upload queue"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        queue.isSuspended = shouldSuspendQueue
        return queue
    }()

    private lazy var foregroundSession: URLSession = {
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        urlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        urlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        urlSessionConfiguration.networkServiceType = .default // dzr .avStreaming
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    var fileUploadedCount = 0
    /// This Realm instance is bound to `dispatchQueue`
    private var realm: Realm!

    private var bestSession: FileUploadSession {
        return Bundle.main.isExtension ? BackgroundUploadSessionManager.instance : foregroundSession
    }

    /// Should suspend operation queue based on network status
    private var shouldSuspendQueue: Bool {
        let status = ReachabilityListener.instance.currentStatus
        return status == .offline || (status != .wifi && UserDefaults.shared.isWifiOnly)
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    private var forceSuspendQueue = false
    var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeProgress: [UUID: (UploadedFileId, UploadProgress) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    public init() {
        // Create Realm
        dispatchQueue.sync {
            do {
                realm = try Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration, queue: dispatchQueue)
            } catch {
                // We can't recover from this error but at least we report it correctly on Sentry
                Logging.reportRealmOpeningError(error, realmConfiguration: DriveFileManager.constants.uploadsRealmConfiguration)
            }
        }
        // Initialize operation queue with files from Realm
        addToQueueFromRealm()
        // Observe network changes
        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] _ in
            self.operationQueue.isSuspended = shouldSuspendQueue || forceSuspendQueue
        }
    }

    // MARK: - Public methods

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
                        // If the upload file has a session URL but it's foreground and doesn't exist anymore (e.g. app was killed), we add it again
                        if uploadFile.sessionUrl.isEmpty || (!uploadFile.sessionUrl.isEmpty && uploadFile.sessionId == self.foregroundSession.identifier && !uploadTasks.contains(where: { $0.originalRequest?.url?.absoluteString == uploadFile.sessionUrl })) {
                            self.addToQueue(file: uploadFile, using: self.realm)
                        }
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

    public func getUploadingFiles(withParent parentId: Int,
                                  userId: Int,
                                  driveId: Int,
                                  using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return getUploadingFiles(userId: userId, driveId: driveId, using: realm).filter("parentDirectoryId = %d", parentId)
    }

    public func getUploadingFiles(userId: Int,
                                  driveId: Int,
                                  using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate = nil AND userId = %d AND driveId = %d", userId, driveId)).sorted(byKeyPath: "taskCreationDate")
    }

    public func getUploadingFiles(userId: Int,
                                  driveIds: [Int],
                                  using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate = nil AND userId = %d AND driveId IN %@", userId, driveIds)).sorted(byKeyPath: "taskCreationDate")
    }

    public func getUploadedFiles(using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate != nil"))
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
                if operation?.isExecuting != true {
                    if let toDelete = realm.object(ofType: UploadFile.self, forPrimaryKey: fileId) {
                        let publishedToDelete = UploadFile(value: toDelete)
                        publishedToDelete.error = .taskCancelled
                        try? realm.safeWrite {
                            realm.delete(toDelete)
                        }
                        self.publishFileUploaded(result: UploadCompletionResult(uploadFile: publishedToDelete, driveFile: nil))
                        self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: realm)
                    }
                }
                operation?.cancel()
        }
    }

    public func cancelAllOperations(withParent parentId: Int,
                                    userId: Int,
                                    driveId: Int) {
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

    public func sendPausedNotificationIfNeeded() {
        dispatchQueue.async {
            if !self.pausedNotificationSent {
                NotificationsHelper.sendPausedUploadQueueNotification()
                self.pausedNotificationSent = true
            }
        }
    }

    func publishProgress(_ progress: Double, for fileId: String) {
        observations.didChangeProgress.values.forEach { closure in
            closure(fileId, progress)
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
        operation.completionBlock = { [parentId = file.parentDirectoryId, fileId = file.id, userId = file.userId, driveId = file.driveId] in
            self.dispatchQueue.async {
                self.operationsInQueue.removeValue(forKey: fileId)
                if operation.result.uploadFile.error != .taskRescheduled {
                    self.publishFileUploaded(result: operation.result)
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: self.realm)
                    OperationQueueHelper.disableIdleTimer(false, queue: self.operationsInQueue)
                }
            }
        }
        operationQueue.addOperation(operation)
        operationsInQueue[file.id] = operation

        publishUploadCount(withParent: file.parentDirectoryId, userId: file.userId, driveId: file.driveId, using: realm)
    }

    private func compactRealmIfNeeded() {
        let compactingCondition: (Int, Int) -> (Bool) = { totalBytes, usedBytes in
            let fiftyMB = 50 * 1024 * 1024
            let compactingNeeded = (totalBytes > fiftyMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
            DDLogInfo("Compacting uploads realm is needed ? \(compactingNeeded)")
            return compactingNeeded
        }

        let config = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent("/uploads.realm"),
            schemaVersion: DriveFileManager.constants.currentUploadDbVersion,
            migrationBlock: DriveFileManager.constants.migrationBlock,
            shouldCompactOnLaunch: compactingCondition,
            objectTypes: [DownloadTask.self, UploadFile.self, PhotoSyncSettings.self]
        )
        do {
            _ = try Realm(configuration: config)
        } catch {
            DDLogError("Failed to compact uploads realm: \(error)")
        }
    }
}
