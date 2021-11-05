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
import RealmSwift

public class UploadQueue {
    public static let instance = UploadQueue()
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
        urlSessionConfiguration.networkServiceType = .default
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    private var fileUploadedCount = 0
    /// This Realm instance is bound to `dispatchQueue`
    private var realm: Realm!

    private var bestSession: FileUploadSession {
        return Constants.isInExtension ? BackgroundUploadSessionManager.instance : foregroundSession
    }

    /// Should suspend operation queue based on network status
    private var shouldSuspendQueue: Bool {
        return ReachabilityListener.instance.currentStatus == .offline
    }

    /// Should suspend operation queue based on explicit `suspendAllOperations()` call
    private var forceSuspendQueue = false
    private var observations = (
        didUploadFile: [UUID: (UploadFile, File?) -> Void](),
        didChangeProgress: [UUID: (UploadedFileId, Progress) -> Void](),
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void](),
        didChangeUploadCountInDrive: [UUID: (Int, Int) -> Void]()
    )

    private init() {
        // Create Realm
        dispatchQueue.sync {
            // swiftlint:disable force_try
            realm = try! Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration, queue: dispatchQueue)
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
                let uploadingFiles = self.realm.objects(UploadFile.self).filter("uploadDate = nil AND maxRetryCount > 0").sorted(byKeyPath: "taskCreationDate")
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

    public func getUploadingFiles(withParent parentId: Int, userId: Int = AccountManager.instance.currentUserId, driveId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return getUploadingFiles(userId: userId, driveId: driveId, using: realm).filter("parentDirectoryId = %d", parentId)
    }

    public func getUploadingFiles(userId: Int, driveId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate = nil AND userId = %d AND driveId = %d", userId, driveId)).sorted(byKeyPath: "taskCreationDate")
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
        dispatchQueue.async { [fileId = file.id, parentId = file.parentDirectoryId, userId = file.userId, driveId = file.driveId, realm = realm!] in
            let operation = self.operationsInQueue[fileId]
            if !(operation?.isExecuting ?? true) {
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

    public func cancelAllOperations(withParent parentId: Int, userId: Int = AccountManager.instance.currentUserId, driveId: Int) {
        dispatchQueue.async {
            self.suspendAllOperations()
            let uploadingFiles = self.getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId, using: self.realm)
            uploadingFiles.forEach { file in
                if !file.isInvalidated,
                   let operation = self.operationsInQueue[file.id] {
                    operation.cancel()
                }
            }
            try? self.realm.safeWrite {
                self.realm.delete(uploadingFiles)
            }
            self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: self.realm)
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
        }
    }

    public func retryAllOperations(withParent parentId: Int, userId: Int = AccountManager.instance.currentUserId, driveId: Int) {
        dispatchQueue.async {
            let failedUploadFiles = self.getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId, using: self.realm).filter("_error != nil")
            try? self.realm.safeWrite {
                failedUploadFiles.forEach { file in
                    file.error = nil
                    file.maxRetryCount = UploadFile.defaultMaxRetryCount
                }
            }
            failedUploadFiles.forEach { self.addToQueue(file: $0, using: self.realm) }
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

        if file.realm == nil {
            // Save drive and directory
            UserDefaults.shared.lastSelectedUser = file.userId
            UserDefaults.shared.lastSelectedDrive = file.driveId
            UserDefaults.shared.lastSelectedDirectory = file.parentDirectoryId
        }

        try? realm.safeWrite {
            if file.realm == nil {
                realm.add(file, update: .modified)
            }
            if file.error != nil {
                file.error = nil
            }
        }

        let operation = UploadOperation(file: file, urlSession: bestSession, itemIdentifier: itemIdentifier)
        operation.queuePriority = file.priority
        operation.completionBlock = { [parentId = file.parentDirectoryId, fileId = file.id, userId = file.userId, driveId = file.driveId] in
            self.dispatchQueue.async {
                self.operationsInQueue.removeValue(forKey: fileId)
                if operation.result.uploadFile.error != .taskRescheduled {
                    self.publishFileUploaded(result: operation.result)
                    self.publishUploadCount(withParent: parentId, userId: userId, driveId: driveId, using: self.realm)
                }
            }
        }
        operationQueue.addOperation(operation)
        operationsInQueue[file.id] = operation

        publishUploadCount(withParent: file.parentDirectoryId, userId: file.userId, driveId: file.driveId, using: realm)
    }

    private func publishUploadCount(withParent parentId: Int, userId: Int, driveId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        realm.refresh()
        publishUploadCountInParent(parentId: parentId, userId: userId, driveId: driveId, using: realm)
        publishUploadCountInDrive(userId: userId, driveId: driveId, using: realm)
    }

    private func publishUploadCountInParent(parentId: Int, userId: Int, driveId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        let uploadCount = getUploadingFiles(withParent: parentId, userId: userId, driveId: driveId, using: realm).count
        observations.didChangeUploadCountInParent.values.forEach { closure in
            closure(parentId, uploadCount)
        }
    }

    private func publishUploadCountInDrive(userId: Int, driveId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        let uploadCount = getUploadingFiles(userId: userId, driveId: driveId, using: realm).count
        observations.didChangeUploadCountInDrive.values.forEach { closure in
            closure(driveId, uploadCount)
        }
    }

    private func publishFileUploaded(result: UploadCompletionResult) {
        sendFileUploadedNotificationIfNeeded(with: result)
        observations.didUploadFile.values.forEach { closure in
            closure(result.uploadFile, result.driveFile)
        }
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

    private func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult) {
        fileUploadedCount += (result.uploadFile.error == nil ? 1 : 0)
        if let error = result.uploadFile.error,
           error != .networkError && error != .taskCancelled && error != .taskRescheduled {
            let uploadedFileName = result.driveFile?.name ?? result.uploadFile.name
            NotificationsHelper.sendUploadError(filename: uploadedFileName, parentId: result.uploadFile.parentDirectoryId, error: error)
            if operationQueue.operationCount == 0 {
                fileUploadedCount = 0
            }
        } else if operationQueue.operationCount == 0 {
            // In some cases fileUploadedCount can be == 1 but the result.uploadFile isn't necessary the last file *successfully* uploaded
            if fileUploadedCount == 1 && result.uploadFile.error == nil {
                let uploadedFileName = result.driveFile?.name ?? result.uploadFile.name
                NotificationsHelper.sendUploadDoneNotification(filename: uploadedFileName, parentId: result.uploadFile.parentDirectoryId)
            } else if fileUploadedCount > 0 {
                NotificationsHelper.sendUploadDoneNotification(uploadCount: fileUploadedCount, parentId: result.uploadFile.parentDirectoryId)
            }
            fileUploadedCount = 0
        }
    }
}

// MARK: - Observation

public extension UploadQueue {
    typealias UploadedFileId = String
    typealias Progress = Double

    @discardableResult
    func observeFileUploaded<T: AnyObject>(_ observer: T, fileId: String? = nil, using closure: @escaping (UploadFile, File?) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didUploadFile[key] = { [weak self, weak observer] uploadFile, driveFile in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didUploadFile.removeValue(forKey: key)
                return
            }

            if fileId == nil || uploadFile.id == fileId {
                closure(uploadFile, driveFile)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didUploadFile.removeValue(forKey: key)
        }
    }

    @discardableResult
    func observeUploadCount<T: AnyObject>(_ observer: T, parentId: Int, using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
        let key = UUID()
        observations.didChangeUploadCountInParent[key] = { [weak self, weak observer] updatedParentId, count in
            guard observer != nil else {
                self?.observations.didChangeUploadCountInParent.removeValue(forKey: key)
                return
            }

            if parentId == updatedParentId {
                closure(updatedParentId, count)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeUploadCountInParent.removeValue(forKey: key)
        }
    }

    @discardableResult
    func observeUploadCount<T: AnyObject>(_ observer: T, driveId: Int, using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
        let key = UUID()
        observations.didChangeUploadCountInDrive[key] = { [weak self, weak observer] updatedDriveId, count in
            guard observer != nil else {
                self?.observations.didChangeUploadCountInDrive.removeValue(forKey: key)
                return
            }

            if driveId == updatedDriveId {
                closure(updatedDriveId, count)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeUploadCountInDrive.removeValue(forKey: key)
        }
    }

    @discardableResult
    func observeFileUploadProgress<T: AnyObject>(_ observer: T, fileId: String? = nil, using closure: @escaping (UploadedFileId, Progress) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didChangeProgress[key] = { [weak self, weak observer] uploadedFileId, progress in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didChangeProgress.removeValue(forKey: key)
                return
            }

            if fileId == nil || uploadedFileId == fileId {
                closure(uploadedFileId, progress)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeProgress.removeValue(forKey: key)
        }
    }
}
