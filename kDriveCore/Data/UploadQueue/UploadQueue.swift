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

import Foundation
import InfomaniakCore
import RealmSwift
import CocoaLumberjackSwift

public class UploadQueue {

    public static let instance = UploadQueue()
    public static let backgroundIdentifier = "com.infomaniak.background.upload"

    public var pausedNotificationSent = false
    private var fileUploadedCount = 0

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
        didChangeUploadCountInParent: [UUID: (Int, Int) -> Void]()
    )

    private class Locks {
        let addToQueueFromRealm = DispatchGroup()
        let addToQueue = DispatchGroup()
    }

    private let locks = Locks()

    private init() {
        // Initialize operation queue with files from Realm
        addToQueueFromRealm()
        // Observe network changes
        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] _ in
            self.operationQueue.isSuspended = shouldSuspendQueue || forceSuspendQueue
        }
    }

    public func waitForCompletion(_ completionHandler: @escaping () -> Void) {
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            completionHandler()
        }
    }

    public func addToQueueFromRealm() {
        DispatchQueue.global(qos: .default).async {
            self.locks.addToQueueFromRealm.performLocked {
                // self.compactRealmIfNeeded()
                BackgroundRealm.uploads.execute { uploadsRealm in
                    let uploadingFiles = uploadsRealm.objects(UploadFile.self).filter("uploadDate = nil AND sessionUrl = \"\" AND maxRetryCount > 0").sorted(byKeyPath: "taskCreationDate")
                    uploadingFiles.forEach { self.addToQueue(file: $0, using: uploadsRealm) }
                }
            }
            DispatchQueue.global(qos: .background).async {
                self.cleanupOrphanFiles()
            }
        }
    }

    public func addToQueue(file: UploadFile) {
        BackgroundRealm.uploads.execute { uploadsRealm in
            addToQueue(file: file, using: uploadsRealm)
        }
    }

    public func addToQueue(file: UploadFile, using realm: Realm) {
        locks.addToQueue.performLocked {
            guard !file.isInvalidated && operationsInQueue[file.id] == nil && file.maxRetryCount > 0 else {
                return
            }

            if file.realm == nil {
                // Save drive and directory
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

            let operation = UploadOperation(file: file, urlSession: bestSession)
            operation.queuePriority = file.priority
            operation.completionBlock = { [parentId = file.parentDirectoryId, fileId = file.id] in
                self.operationsInQueue.removeValue(forKey: fileId)
                self.publishFileUploaded(result: operation.result)
                BackgroundRealm.uploads.execute { realm in
                    self.publishUploadCount(withParent: parentId, using: realm)
                }
            }
            operationQueue.addOperation(operation)
            operationsInQueue[file.id] = operation

            publishUploadCount(withParent: file.parentDirectoryId, using: realm)
        }
    }

    public func getUploadingFiles(withParent parentId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) -> Results<UploadFile> {
        if let driveId = AccountManager.instance.currentDriveFileManager?.drive.id {
            let userId = AccountManager.instance.currentAccount.user.id
            return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate = nil AND parentDirectoryId = %d AND userId = %d AND driveId = %d", parentId, userId, driveId)).sorted(byKeyPath: "taskCreationDate")
        } else {
            return realm.objects(UploadFile.self).filter("FALSEPREDICATE")
        }
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

    public func cancel(_ file: UploadFile, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        locks.addToQueue.performLocked {
            guard !file.isInvalidated else { return }
            if let operation = operationsInQueue[file.id] {
                operation.cancel()
            } else {
                let parentId = file.parentDirectoryId
                autoreleasepool {
                    try? realm.safeWrite {
                        realm.delete(file)
                    }
                }
                publishUploadCount(withParent: parentId)
            }
        }
    }

    public func cancelAllOperations(withParent parentId: Int) {
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            self.suspendAllOperations()
            BackgroundRealm.uploads.execute { uploadsRealm in
                let uploadingFiles = self.getUploadingFiles(withParent: parentId, using: uploadsRealm)
                uploadingFiles.forEach { file in
                    if !file.isInvalidated,
                        let operation = self.operationsInQueue[file.id] {
                        operation.cancel()
                    }
                }
                try? uploadsRealm.safeWrite {
                    uploadsRealm.delete(uploadingFiles)
                }
                publishUploadCount(withParent: parentId, using: uploadsRealm)
            }
            self.resumeAllOperations()
        }
    }

    public func retry(_ file: UploadFile, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        try? realm.safeWrite {
            file.error = nil
            file.maxRetryCount = UploadFile.defaultMaxRetryCount
        }
        addToQueue(file: file)
    }

    public func retryAllOperations(withParent parentId: Int) {
        BackgroundRealm.uploads.execute { realm in
            let failedUploadFiles = getUploadingFiles(withParent: parentId, using: realm).filter("_error != nil")
            try? realm.safeWrite {
                failedUploadFiles.forEach { file in
                    file.error = nil
                    file.maxRetryCount = UploadFile.defaultMaxRetryCount
                }
            }
            failedUploadFiles.forEach { addToQueue(file: $0) }
        }
    }

    public func sendPausedNotificationIfNeeded() {
        if !pausedNotificationSent {
            NotificationsHelper.sendPausedUploadQueueNotification()
            pausedNotificationSent = true
        }
    }

    private func sendFileUploadedNotificationIfNeeded(with result: UploadCompletionResult) {
        fileUploadedCount += (result.uploadFile.error == nil ? 1 : 0)
        if let error = result.uploadFile.error,
            error != .networkError || error != .taskCancelled || error != .taskRescheduled {
            NotificationsHelper.sendUploadError(filename: result.uploadFile.name, parentId: result.uploadFile.parentDirectoryId, error: error)
            if operationQueue.operationCount == 0 {
                fileUploadedCount = 0
            }
        } else if operationQueue.operationCount == 0 {
            if fileUploadedCount == 1 {
                NotificationsHelper.sendUploadDoneNotification(filename: result.uploadFile.name, parentId: result.uploadFile.parentDirectoryId)
            } else {
                NotificationsHelper.sendUploadDoneNotification(uploadCount: fileUploadedCount, parentId: result.uploadFile.parentDirectoryId)
            }
            fileUploadedCount = 0
        }
    }

    private func publishUploadCount(withParent parentId: Int, using realm: Realm = DriveFileManager.constants.uploadsRealm) {
        let uploadCount = getUploadingFiles(withParent: parentId, using: realm).count
        observations.didChangeUploadCountInParent.values.forEach { closure in
            closure(parentId, uploadCount)
        }
    }

    private func publishFileUploaded(result: UploadCompletionResult) {
        sendFileUploadedNotificationIfNeeded(with: result)
        observations.didUploadFile.values.forEach { closure in
            closure(result.uploadFile, result.driveFile)
        }
    }

    func publishProgress(_ progress: Double, for fileId: String) {
        observations.didChangeProgress.values.forEach { closure in
            closure(fileId, progress)
        }
    }

    private func cleanupOrphanFiles() {
        let importDirectory = DriveFileManager.constants.importDirectoryURL
        let importedFiles = (try? FileManager.default.contentsOfDirectory(atPath: importDirectory.path)) ?? []

        autoreleasepool {
            let realm = DriveFileManager.constants.uploadsRealm
            for file in importedFiles {
                let filePath = importDirectory.appendingPathComponent(file, isDirectory: false).path
                if realm.objects(UploadFile.self).filter(NSPredicate(format: "url = %@", filePath)).isEmpty {
                    try? FileManager.default.removeItem(atPath: filePath)
                }
            }
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
            objectTypes: [DownloadTask.self, UploadFile.self, PhotoSyncSettings.self])
        do {
            _ = try Realm(configuration: config)
        } catch {
            DDLogError("Failed to compact uploads realm: \(error)")
        }
    }

}

// MARK: - Observation

extension UploadQueue {

    public typealias UploadedFileId = String
    public typealias Progress = Double

    @discardableResult
    public func observeFileUploaded<T: AnyObject>(_ observer: T, fileId: String? = nil, using closure: @escaping (UploadFile, File?) -> Void)
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
    public func observeUploadCountInParent<T: AnyObject>(_ observer: T, parentId: Int, using closure: @escaping (Int, Int) -> Void) -> ObservationToken {
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
    public func observeFileUploadProgress<T: AnyObject>(_ observer: T, fileId: String? = nil, using closure: @escaping (UploadedFileId, Progress) -> Void)
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
