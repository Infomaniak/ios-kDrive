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
import FileProvider
import Foundation
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
// import RealmSwift

/// Something that can download a file.
public protocol DownloadOperationable: Operationable {
    /// Called upon request completion
    func downloadCompletion(url: URL?, response: URLResponse?, error: Error?)

    var file: File { get }
}

public class DownloadOperation: Operation, DownloadOperationable {
    // MARK: - Attributes

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var downloadManager: BackgroundDownloadSessionManager

    private let driveFileManager: DriveFileManager
    private let urlSession: FileDownloadSession
    private let itemIdentifier: NSFileProviderItemIdentifier?
    private var progressObservation: NSKeyValueObservation?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    public let file: File
    public var task: URLSessionDownloadTask?
    public var error: DriveError?

    public var fileId: Int {
        return file.id
    }

    private var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }

    override public var isExecuting: Bool {
        return _executing
    }

    override public var isFinished: Bool {
        return _finished
    }

    override public var isAsynchronous: Bool {
        return true
    }

    // MARK: - Public methods

    public init(file: File, driveFileManager: DriveFileManager, urlSession: FileDownloadSession, itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        self.file = File(value: file)
        self.driveFileManager = driveFileManager
        self.urlSession = urlSession
        self.itemIdentifier = itemIdentifier
    }

    public init(file: File, driveFileManager: DriveFileManager, task: URLSessionDownloadTask, urlSession: FileDownloadSession) {
        self.file = file
        self.driveFileManager = driveFileManager
        self.urlSession = urlSession
        self.task = task
        self.itemIdentifier = nil
    }

    override public func start() {
        assert(!isExecuting, "Operation is already started")

        DDLogInfo("[DownloadOperation] Download of \(file.id) started")
        // Always check for cancellation before launching the task
        if isCancelled {
            DDLogInfo("[DownloadOperation] Download of \(file.id) canceled")
            // Must move the operation to the finished state if it is canceled.
            end(sessionUrl: nil)
            return
        }

        if !Bundle.main.isExtension {
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "File Downloader") {
                DownloadQueue.instance.suspendAllOperations()
                DDLogInfo("[DownloadOperation] Background task expired")
                if let rescheduledSessionId = self.downloadManager.rescheduleForBackground(task: self.task),
                   let task = self.task,
                   let sessionUrl = task.originalRequest?.url?.absoluteString {
                    self.error = .taskRescheduled

                    let downloadTask = DownloadTask(fileId: self.file.id, isDirectory: self.file.isDirectory, driveId: self.file.driveId, userId: self.driveFileManager.drive.userId, sessionId: rescheduledSessionId, sessionUrl: sessionUrl)
                    BackgroundRealm.uploads.execute { realm in
                        try? realm.safeWrite {
                            realm.add(downloadTask, update: .modified)
                        }
                    }
                } else {
                    // We couldn't reschedule the download
                    // TODO: Send notification to tell the user the download failed ?
                }
                self.end(sessionUrl: self.task?.originalRequest?.url)
            }
        }

        // If the operation is not canceled, begin executing the task
        _executing = true
        main()
    }

    private func getToken() -> ApiToken? {
        var apiToken: ApiToken?
        if let userToken = accountManager.getTokenForUserId(driveFileManager.drive.userId) {
            let lock = DispatchGroup()
            lock.enter()
            driveFileManager.apiFetcher.performAuthenticatedRequest(token: userToken) { token, _ in
                apiToken = token
                lock.leave()
            }
            lock.wait()
        }

        return apiToken
    }

    override public func main() {
        DDLogInfo("[DownloadOperation] Downloading \(file.id) with session \(urlSession.identifier)")

        let url = Endpoint.download(file: file).url

        // Add download task to Realm
        let downloadTask = DownloadTask(fileId: file.id, isDirectory: file.isDirectory, driveId: file.driveId, userId: driveFileManager.drive.userId, sessionId: urlSession.identifier, sessionUrl: url.absoluteString)
        BackgroundRealm.uploads.execute { realm in
            try? realm.safeWrite {
                realm.add(downloadTask, update: .modified)
            }
        }

        if let token = getToken() {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
            task = urlSession.downloadTask(with: request, completionHandler: downloadCompletion)
            progressObservation = task?.progress.observe(\.fractionCompleted, options: .new) { [fileId = file.id] _, value in
                guard let newValue = value.newValue else {
                    return
                }
                DownloadQueue.instance.publishProgress(newValue, for: fileId)
            }
            if let itemIdentifier = itemIdentifier {
                DriveInfosManager.instance.getFileProviderManager(for: driveFileManager.drive) { manager in
                    manager.register(self.task!, forItemWithIdentifier: itemIdentifier) { _ in }
                }
            }
            task?.resume()
        } else {
            error = .localError // Other error?
            end(sessionUrl: url)
        }
    }

    override public func cancel() {
        DDLogInfo("[DownloadOperation] Download of \(file.id) canceled")
        super.cancel()
        task?.cancel()
    }

    // MARK: - methods

    public func downloadCompletion(url: URL?, response: URLResponse?, error: Error?) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if let error = error {
            // Client-side error
            DDLogError("[DownloadOperation] Client-side error for \(file.id): \(error)")
            if self.error == .taskRescheduled {
                // We return because we don't want end() to be called as it is already called in the expiration handler
                return
            } else if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                self.error = .taskCancelled
            } else {
                self.error = .networkError
            }
        } else if let url = url {
            // Success
            DDLogInfo("[DownloadOperation] Download of \(file.id) successful")
            do {
                if file.isDirectory {
                    try moveFileToTemporaryDirectory(downloadPath: url)
                } else {
                    try moveFileToCache(downloadPath: url)
                }
            } catch {
                DDLogError("[DownloadOperation] Error moving file \(file.id): \(error)")
                self.error = .localError
            }
        } else {
            // Server-side error
            DDLogError("[DownloadOperation] Server error for \(file.id) (code: \(statusCode))")
            self.error = .serverError
        }
        end(sessionUrl: task?.originalRequest?.url)
    }

    private func moveFileToCache(downloadPath: URL) throws {
        try FileManager.default.removeItemIfExists(at: file.localContainerUrl)
        try FileManager.default.createDirectory(at: file.localContainerUrl, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: downloadPath, to: file.localUrl)
        file.applyLastModifiedDateToLocalFile()
        file.excludeFileFromSystemBackup()
    }

    private func moveFileToTemporaryDirectory(downloadPath: URL) throws {
        try FileManager.default.removeItemIfExists(at: file.temporaryContainerUrl)
        try FileManager.default.createDirectory(at: file.temporaryContainerUrl, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: downloadPath, to: file.temporaryUrl)
    }

    private func end(sessionUrl: URL?) {
        DDLogInfo("[DownloadOperation] Download of \(file.id) ended")
        // Delete download task
        if error != .taskRescheduled,
           let sessionUrl = sessionUrl {
            BackgroundRealm.uploads.execute { realm in
                if let task = realm.objects(DownloadTask.self).filter(NSPredicate(format: "sessionUrl = %@", sessionUrl.absoluteString)).first {
                    try? realm.safeWrite {
                        realm.delete(task)
                    }
                }
            }
        }

        progressObservation?.invalidate()
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
        _executing = false
        _finished = true
    }
}
