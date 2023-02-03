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

import FileProvider
import Foundation
import InfomaniakCore
import InfomaniakDI
import RealmSwift

public class DownloadTask: Object {
    @Persisted(primaryKey: true) var fileId: Int = 0
    @Persisted var isDirectory = false
    @Persisted var driveId: Int = 0
    @Persisted var userId: Int = 0
    @Persisted var sessionUrl: String = ""
    @Persisted var sessionId: String?

    convenience init(fileId: Int, isDirectory: Bool, driveId: Int, userId: Int, sessionId: String, sessionUrl: String) {
        self.init()
        self.fileId = fileId
        self.isDirectory = isDirectory
        self.driveId = driveId
        self.sessionId = sessionId
        self.sessionUrl = sessionUrl
        self.userId = userId
    }
}

public final class DownloadQueue {
    // MARK: - Attributes

    @InjectService var accountManager: AccountManageable

    public static let instance = DownloadQueue()
    public static let backgroundIdentifier = "com.infomaniak.background.download"

    public private(set) var operationsInQueue: [Int: DownloadOperation] = [:]
    public private(set) var archiveOperationsInQueue: [String: DownloadArchiveOperation] = [:]
    private(set) lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kDrive download queue"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()

    private let dispatchQueue = DispatchQueue(label: "com.infomaniak.drive.download-sync", autoreleaseFrequency: .workItem)

    private lazy var foregroundSession: URLSession = {
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = false
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()

    private var observations = (
        didDownloadFile: [UUID: (DownloadedFileId, DriveError?) -> Void](),
        didChangeProgress: [UUID: (DownloadedFileId, Double) -> Void](),
        didDownloadArchive: [UUID: (DownloadedArchiveId, URL?, DriveError?) -> Void](),
        didChangeArchiveProgress: [UUID: (DownloadedArchiveId, Double) -> Void]()
    )
    private var bestSession: FileDownloadSession {
        if Bundle.main.isExtension {
            return InjectService<BackgroundDownloadSessionManager>().wrappedValue
        } else {
            return foregroundSession
        }
    }

    // MARK: - Public methods

    public func addToQueue(file: File,
                           userId: Int,
                           itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        dispatchQueue.async { [driveId = file.driveId, fileId = file.id, isManagedByRealm = file.isManagedByRealm] in
            guard let drive = self.accountManager.getDrive(for: userId, driveId: driveId, using: nil),
                  let driveFileManager = self.accountManager.getDriveFileManager(for: drive),
                  let file = isManagedByRealm ? driveFileManager.getCachedFile(id: fileId) : file,
                  !self.hasOperation(for: file) else {
                return
            }

            OperationQueueHelper.disableIdleTimer(true)

            let operation = DownloadOperation(file: file, driveFileManager: driveFileManager, urlSession: self.bestSession, itemIdentifier: itemIdentifier)
            operation.completionBlock = {
                self.dispatchQueue.async {
                    self.operationsInQueue.removeValue(forKey: fileId)
                    self.publishFileDownloaded(fileId: fileId, error: operation.error)
                    OperationQueueHelper.disableIdleTimer(false, queue: self.operationsInQueue)
                }
            }
            self.operationQueue.addOperation(operation)
            self.operationsInQueue[file.id] = operation
        }
    }

    public func addToQueue(archiveId: String, driveId: Int, userId: Int) {
        dispatchQueue.async {
            guard let drive = self.accountManager.getDrive(for: userId, driveId: driveId, using: nil),
                  let driveFileManager = self.accountManager.getDriveFileManager(for: drive) else {
                return
            }

            OperationQueueHelper.disableIdleTimer(true)

            let operation = DownloadArchiveOperation(archiveId: archiveId, driveFileManager: driveFileManager, urlSession: self.bestSession)
            operation.completionBlock = {
                self.dispatchQueue.async {
                    self.archiveOperationsInQueue.removeValue(forKey: archiveId)
                    self.publishArchiveDownloaded(archiveId: archiveId, archiveUrl: operation.archiveUrl, error: operation.error)
                    OperationQueueHelper.disableIdleTimer(false, queue: self.operationsInQueue)
                }
            }
            self.operationQueue.addOperation(operation)
            self.archiveOperationsInQueue[archiveId] = operation
        }
    }

    public func temporaryDownload(file: File,
                                  userId: Int,
                                  onOperationCreated: ((DownloadOperation?) -> Void)? = nil,
                                  completion: @escaping (DriveError?) -> Void) {
        dispatchQueue.async(qos: .userInitiated) { [driveId = file.driveId, fileId = file.id, isManagedByRealm = file.isManagedByRealm] in
            guard let drive = self.accountManager.getDrive(for: userId, driveId: driveId, using: nil),
                  let driveFileManager = self.accountManager.getDriveFileManager(for: drive),
                  let file = isManagedByRealm ? driveFileManager.getCachedFile(id: fileId) : file,
                  !self.hasOperation(for: file) else {
                return
            }

            OperationQueueHelper.disableIdleTimer(true)

            let operation = DownloadOperation(file: file, driveFileManager: driveFileManager, urlSession: self.foregroundSession)
            operation.completionBlock = {
                self.dispatchQueue.async {
                    self.operationsInQueue.removeValue(forKey: fileId)
                    OperationQueueHelper.disableIdleTimer(false, queue: self.operationsInQueue)
                    completion(operation.error)
                }
            }
            operation.start()
            self.operationsInQueue[file.id] = operation
            onOperationCreated?(operation)
        }
    }

    public func suspendAllOperations() {
        operationQueue.isSuspended = true
    }

    public func resumeAllOperations() {
        operationQueue.isSuspended = false
    }

    public func cancelAllOperations() {
        operationQueue.cancelAllOperations()
    }

    public func cancelRunningOperations() {
        operationQueue.operations.filter(\.isExecuting).forEach { $0.cancel() }
    }

    public func operation(for file: File) -> DownloadOperation? {
        return operationsInQueue[file.id]
    }

    public func hasOperation(for file: File) -> Bool {
        return operation(for: file) != nil
    }

    // MARK: - Private methods

    private init() {}

    private func publishFileDownloaded(fileId: Int, error: DriveError?) {
        observations.didDownloadFile.values.forEach { closure in
            closure(fileId, error)
        }
    }

    func publishProgress(_ progress: Double, for fileId: Int) {
        observations.didChangeProgress.values.forEach { closure in
            closure(fileId, progress)
        }
    }

    private func publishArchiveDownloaded(archiveId: String, archiveUrl: URL?, error: DriveError?) {
        observations.didDownloadArchive.values.forEach { closure in
            closure(archiveId, archiveUrl, error)
        }
    }

    func publishProgress(_ progress: Double, for archiveId: String) {
        observations.didChangeArchiveProgress.values.forEach { closure in
            closure(archiveId, progress)
        }
    }
}

// MARK: - Observation

public extension DownloadQueue {
    typealias DownloadedFileId = Int
    typealias DownloadedArchiveId = String

    @discardableResult
    func observeFileDownloaded<T: AnyObject>(_ observer: T,
                                             fileId: Int? = nil,
                                             using closure: @escaping (DownloadedFileId, DriveError?) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didDownloadFile[key] = { [weak self, weak observer] downloadedFileId, error in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didDownloadFile.removeValue(forKey: key)
                return
            }

            if fileId == nil || downloadedFileId == fileId {
                closure(downloadedFileId, error)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didDownloadFile.removeValue(forKey: key)
        }
    }

    @discardableResult
    func observeFileDownloadProgress<T: AnyObject>(_ observer: T,
                                                   fileId: Int? = nil,
                                                   using closure: @escaping (DownloadedFileId, Double) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didChangeProgress[key] = { [weak self, weak observer] downloadedFileId, progress in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didChangeProgress.removeValue(forKey: key)
                return
            }

            if fileId == nil || downloadedFileId == fileId {
                closure(downloadedFileId, progress)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeProgress.removeValue(forKey: key)
        }
    }

    @discardableResult
    func observeArchiveDownloaded<T: AnyObject>(_ observer: T,
                                                archiveId: String? = nil,
                                                using closure: @escaping (DownloadedArchiveId, URL?, DriveError?) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didDownloadArchive[key] = { [weak self, weak observer] downloadedArchiveId, archiveUrl, error in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didDownloadArchive.removeValue(forKey: key)
                return
            }

            if archiveId == nil || downloadedArchiveId == archiveId {
                closure(downloadedArchiveId, archiveUrl, error)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didDownloadArchive.removeValue(forKey: key)
        }
    }

    @discardableResult
    func observeArchiveDownloadProgress<T: AnyObject>(_ observer: T, archiveId: String? = nil, using closure: @escaping (DownloadedArchiveId, Double) -> Void)
        -> ObservationToken {
        let key = UUID()
        observations.didChangeArchiveProgress[key] = { [weak self, weak observer] downloadedArchiveId, progress in
            // If the observer has been deallocated, we can
            // automatically remove the observation closure.
            guard observer != nil else {
                self?.observations.didChangeArchiveProgress.removeValue(forKey: key)
                return
            }

            if archiveId == nil || downloadedArchiveId == archiveId {
                closure(downloadedArchiveId, progress)
            }
        }

        return ObservationToken { [weak self] in
            self?.observations.didChangeArchiveProgress.removeValue(forKey: key)
        }
    }
}
