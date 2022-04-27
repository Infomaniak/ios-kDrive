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

import Alamofire
import CocoaLumberjackSwift
import Foundation
import InfomaniakCore
import RealmSwift
import Sentry

public class UploadTokenManager {
    public static let instance = UploadTokenManager()

    private var tokens: [Int: UploadToken] = [:]
    private var lock = DispatchGroup()

    public func getToken(userId: Int, driveId: Int, completionHandler: @escaping (UploadToken?) -> Void) {
        lock.wait()
        lock.enter()
        if let token = tokens[userId], !token.isNearlyExpired {
            completionHandler(token)
            lock.leave()
        } else if let userToken = AccountManager.instance.getTokenForUserId(userId),
                  let drive = AccountManager.instance.getDrive(for: userId, driveId: driveId),
                  let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive) {
            driveFileManager.apiFetcher.getPublicUploadToken(with: userToken, drive: drive) { result in
                switch result {
                case .success(let token):
                    self.tokens[userId] = token
                    completionHandler(token)
                case .failure(let error):
                    DDLogError("[UploadOperation] Error while trying to get upload token: \(error)")
                    completionHandler(nil)
                }
                self.lock.leave()
            }
        } else {
            completionHandler(nil)
            lock.leave()
        }
    }
}

public struct UploadCompletionResult {
    var uploadFile: UploadFile!
    var driveFile: File?
}

public class UploadOperation: Operation {
    // MARK: - Attributes

    private var file: UploadFile
    private let urlSession: FileUploadSession
    private let itemIdentifier: NSFileProviderItemIdentifier?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var uploadToken: UploadToken?
    private var task: URLSessionUploadTask?
    private var progressObservation: NSKeyValueObservation?

    public var result: UploadCompletionResult

    private let completionLock = DispatchGroup()

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

    public init(file: UploadFile, urlSession: FileUploadSession = URLSession.shared, itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        self.file = UploadFile(value: file)
        self.urlSession = urlSession
        self.itemIdentifier = itemIdentifier
        self.result = UploadCompletionResult()
    }

    public init(file: UploadFile, task: URLSessionUploadTask, urlSession: FileUploadSession = URLSession.shared) {
        self.file = UploadFile(value: file)
        self.file.error = nil
        self.task = task
        self.urlSession = urlSession
        self.itemIdentifier = nil
        self.result = UploadCompletionResult()
    }

    override public func start() {
        assert(!isExecuting, "Operation is already started")

        DDLogInfo("[UploadOperation] Job \(file.id) started")
        // Always check for cancellation before launching the task
        if isCancelled {
            DDLogInfo("[UploadOperation] Job \(file.id) canceled")
            // Must move the operation to the finished state if it is canceled.
            file.error = .taskCancelled
            end()
            return
        }

        // Start background task
        if !Bundle.main.isExtension {
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "File Uploader",
                                                                                expirationHandler: backgroundTaskExpired)
        }

        getUploadTokenSync()
        getPhAssetIfNeeded()

        // If the operation is not canceled, begin executing the task
        _executing = true
        main()
    }

    override public func main() {
        DDLogInfo("[UploadOperation] Executing job \(file.id)")
        file.maxRetryCount -= 1
        guard let token = uploadToken else {
            DDLogError("[UploadOperation] Failed to fetch upload token for job \(file.id)")
            file.error = .refreshToken
            end()
            return
        }

        let url = Endpoint.directUpload(file: file).url
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization")

        file.sessionUrl = url.absoluteString
        file.sessionId = urlSession.identifier

        if let filePath = file.pathURL,
           FileManager.default.isReadableFile(atPath: filePath.path) {
            task = urlSession.uploadTask(with: request, fromFile: filePath, completionHandler: uploadCompletion)
            task?.countOfBytesClientExpectsToSend = file.size + 512 // Extra 512 bytes for request headers
            task?.countOfBytesClientExpectsToReceive = 1024 * 5 // 5KB is a very reasonable upper bound size for a file server response (max observed: 1.47KB)
            progressObservation = task?.progress.observe(\.fractionCompleted, options: .new) { [fileId = file.id] _, value in
                guard let newValue = value.newValue else {
                    return
                }
                UploadQueue.instance.publishProgress(newValue, for: fileId)
            }
            if let itemIdentifier = itemIdentifier, let task = task {
                DriveInfosManager.instance.getFileProviderManager(driveId: file.driveId, userId: file.userId) { manager in
                    manager.register(task, forItemWithIdentifier: itemIdentifier) { _ in }
                }
            }
            task?.resume()

            // Save UploadFile state (we are mainly interested in saving sessionUrl)
            BackgroundRealm.uploads.execute { uploadsRealm in
                try? uploadsRealm.safeWrite {
                    uploadsRealm.add(UploadFile(value: file), update: .modified)
                }
            }
        } else {
            DDLogError("[UploadOperation] No file path found for job \(file.id)")
            file.error = .fileNotFound
            end()
        }
    }

    override public func cancel() {
        DDLogInfo("[UploadOperation] Job \(file.id) canceled")
        super.cancel()
        task?.cancel()
    }

    // MARK: - Private methods

    private func getUploadTokenSync() {
        let syncToken = DispatchGroup()
        syncToken.enter()
        UploadTokenManager.instance.getToken(userId: file.userId, driveId: file.driveId) { token in
            self.uploadToken = token
            syncToken.leave()
        }
        syncToken.wait()
    }

    private func getPhAssetIfNeeded() {
        if file.type == .phAsset && file.pathURL == nil {
            DDLogInfo("[UploadOperation] Need to fetch photo asset")
            if let asset = file.getPHAsset(),
               let url = PhotoLibraryUploader.instance.getUrlSync(for: asset) {
                DDLogInfo("[UploadOperation] Got photo asset, writing URL")
                file.pathURL = url
            } else {
                DDLogError("[UploadOperation] Failed to get photo asset")
            }
        }
    }

    func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        completionLock.wait()
        // Task has called end() in backgroundTaskExpired
        guard !isFinished else { return }
        completionLock.enter()

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if let error = error {
            // Client-side error
            DDLogError("[UploadOperation] Client-side error for job \(file.id): \(error)")
            if file.error != .taskRescheduled {
                file.sessionUrl = ""
            } else {
                // We return because we don't want end() to be called as it is already called in the expiration handler
                completionLock.leave()
                return
            }
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
                if file.error != .taskExpirationCancelled && file.error != .taskRescheduled {
                    file.error = .taskCancelled
                    file.maxRetryCount = 0
                }
            } else {
                file.error = .networkError
            }
        } else if let data = data,
                  let response = try? ApiFetcher.decoder.decode(ApiResponse<[File]>.self, from: data),
                  let driveFile = response.data?.first {
            // Success
            DDLogInfo("[UploadOperation] Job \(file.id) successful")
            file.uploadDate = Date()
            file.error = nil
            if let driveFileManager = AccountManager.instance.getDriveFileManager(for: file.driveId, userId: file.userId) {
                // File is already or has parent in DB let's update it
                let queue = BackgroundRealm.getQueue(for: driveFileManager.realmConfiguration)
                queue.execute { realm in
                    if driveFileManager.getCachedFile(id: driveFile.id, freeze: false, using: realm) != nil || file.relativePath.isEmpty {
                        let parent = driveFileManager.getCachedFile(id: file.parentDirectoryId, freeze: false, using: realm)
                        queue.bufferedWrite(in: parent, file: driveFile)
                        result.driveFile = File(value: driveFile)
                    }
                }
            }
        } else {
            // Server-side error
            var error = DriveError.serverError
            if let data = data,
               let apiError = try? ApiFetcher.decoder.decode(ApiResponse<Empty>.self, from: data).error {
                error = DriveError(apiError: apiError)
            }
            DDLogError("[UploadOperation] Server error for job \(file.id) (code: \(statusCode)): \(error)")
            file.sessionUrl = ""
            file.error = error
            if error == .quotaExceeded {
                file.maxRetryCount = 0
            } else if error == .objectNotFound {
                // If we get an ”object not found“ error, we cancel all further uploads in this folder
                file.maxRetryCount = 0
                UploadQueue.instance.cancelAllOperations(withParent: file.parentDirectoryId, userId: file.userId, driveId: file.driveId)
                if PhotoLibraryUploader.instance.isSyncEnabled && PhotoLibraryUploader.instance.settings?.parentDirectoryId == file.parentDirectoryId {
                    PhotoLibraryUploader.instance.disableSync()
                    NotificationsHelper.sendPhotoSyncErrorNotification()
                }
            }
        }

        end()
        completionLock.leave()
    }

    private func backgroundTaskExpired() {
        completionLock.wait()
        // Task has called end() in uploadCompletion
        guard !isFinished else { return }
        completionLock.enter()

        DDLogInfo("[UploadOperation] Background task expired")
        let breadcrumb = Breadcrumb(level: .info, category: "BackgroundUploadTask")
        breadcrumb.message = "Rescheduling file \(file.name)"
        breadcrumb.data = ["File id": file.id,
                           "File name": file.name,
                           "File size": file.size,
                           "File type": file.type.rawValue]
        SentrySDK.addBreadcrumb(crumb: breadcrumb)

        file.error = .taskRescheduled
        // Cancel the task before creating a background upload task to avoid duplicated files
        task?.cancel()

        let rescheduledSessionId = BackgroundUploadSessionManager.instance.rescheduleForBackground(task: task, fileUrl: file.pathURL)
        if let sessionId = rescheduledSessionId {
            file.sessionId = sessionId
        } else {
            file.sessionUrl = ""
            file.error = .taskExpirationCancelled
            UploadQueue.instance.sendPausedNotificationIfNeeded()
        }
        UploadQueue.instance.suspendAllOperations()
        end()
        completionLock.leave()
        DDLogInfo("[UploadOperation] Expiration handler end block job \(file.id)")
    }

    private func end() {
        DDLogInfo("[UploadOperation] Job \(file.id) ended error: \(file.error?.code ?? "")")

        if let path = file.pathURL,
           file.shouldRemoveAfterUpload && (file.error == nil || file.error == .taskCancelled) {
            try? FileManager.default.removeItem(at: path)
        }

        // Save upload file
        result.uploadFile = UploadFile(value: file)
        if file.error != .taskCancelled {
            BackgroundRealm.uploads.execute { uploadsRealm in
                try? uploadsRealm.safeWrite {
                    uploadsRealm.add(UploadFile(value: file), update: .modified)
                }
            }
        } else {
            BackgroundRealm.uploads.execute { uploadsRealm in
                if let toDelete = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: file.id) {
                    try? uploadsRealm.safeWrite {
                        uploadsRealm.delete(toDelete)
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
