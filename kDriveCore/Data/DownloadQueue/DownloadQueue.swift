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
import FileProvider
import RealmSwift

public class DownloadTask: Object {

    @objc public dynamic var fileId: Int = 0
    @objc public dynamic var driveId: Int = 0
    @objc public dynamic var userId: Int = 0
    @objc public dynamic var sessionUrl: String = ""

    init(fileId: Int, driveId: Int, userId: Int, sessionUrl: String) {
        self.fileId = fileId
        self.driveId = driveId
        self.sessionUrl = sessionUrl
        self.userId = userId
    }

    public override init() {
    }

}

public class DownloadQueue {

    // MARK: - Attributes

    public static let instance = DownloadQueue()
    public static let backgroundIdentifier = "com.infomaniak.background.download"

    private(set) public var operationsInQueue: [Int: DownloadOperation] = [:]
    private(set) lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kDrive download queue"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    private lazy var foregroundSession: URLSession = {
        let urlSessionConfiguration = URLSessionConfiguration.default
        urlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = false
        urlSessionConfiguration.allowsCellularAccess = true
        urlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        return URLSession(configuration: urlSessionConfiguration, delegate: nil, delegateQueue: nil)
    }()
    private var observations = (
        didDownloadFile: [UUID: (DownloadedFileId, DriveError?) -> Void](),
        didChangeProgress: [UUID: (DownloadedFileId, Double) -> Void]()
    )

    // MARK: - Public methods

    public func addToQueue(file: File, userId: Int = AccountManager.instance.currentUserId, itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        guard !file.isInvalidated && operationsInQueue[file.id] == nil,
            let drive = AccountManager.instance.getDrive(for: userId, driveId: file.driveId),
            let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive) else {
            return
        }

        let operation = DownloadOperation(file: file, driveFileManager: driveFileManager, urlSession: BackgroundDownloadSessionManager.instance, itemIdentifier: itemIdentifier)
        operation.completionBlock = { [fileId = file.id] in
            self.operationsInQueue.removeValue(forKey: fileId)
            self.publishFileDownloaded(fileId: fileId, error: operation.error)
        }
        operationQueue.addOperation(operation)
        operationsInQueue[file.id] = operation
    }

    public func temporaryDownload(file: File, completion: @escaping (DriveError?) -> Void) -> DownloadOperation? {
        guard !file.isInvalidated && operationsInQueue[file.id] == nil,
            let driveFileManager = AccountManager.instance.currentDriveFileManager else {
            return nil
        }

        let operation = DownloadOperation(file: file, driveFileManager: driveFileManager, urlSession: foregroundSession)
        operation.completionBlock = { [fileId = file.id] in
            self.operationsInQueue.removeValue(forKey: fileId)
            completion(operation.error)
        }
        operation.start()
        operationsInQueue[file.id] = operation
        return operation
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

    // MARK: - Private methods

    private init() { }

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
}

// MARK: - Observation

extension DownloadQueue {

    public typealias DownloadedFileId = Int

    @discardableResult
    public func observeFileDownloaded<T: AnyObject>(_ observer: T, fileId: Int? = nil, using closure: @escaping (DownloadedFileId, DriveError?) -> Void)
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
    public func observeFileDownloadProgress<T: AnyObject>(_ observer: T, fileId: Int? = nil, using closure: @escaping (DownloadedFileId, Double) -> Void)
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
}
