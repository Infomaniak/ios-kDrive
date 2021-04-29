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
            driveFileManager.apiFetcher.getPublicUploadTokenWithToken(userToken) { (response, error) in
                let token = response?.data
                self.tokens[userId] = token
                completionHandler(token)
                self.lock.leave()
            }
        } else {
            completionHandler(nil)
            lock.leave()
        }
    }
}

public struct FileUploadCompletionResult {
    var uploadFile: UploadFile!
    var driveFile: File? = nil
}

public class FileUploader: Operation {

    // MARK: - Attributes

    private var file: UploadFile
    private let urlSession: FileUploadSession
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var uploadToken: UploadToken?
    private var task: URLSessionUploadTask?
    private var progressObservation: NSKeyValueObservation?

    public var result: FileUploadCompletionResult

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

    public override var isExecuting: Bool {
        return _executing
    }

    public override var isFinished: Bool {
        return _finished
    }

    public override var isAsynchronous: Bool {
        return true
    }

    // MARK: - Public methods

    public init(file: UploadFile, urlSession: FileUploadSession = URLSession.shared) {
        self.file = UploadFile(value: file)
        self.urlSession = urlSession
        self.result = FileUploadCompletionResult()
    }

    public init(file: UploadFile, task: URLSessionUploadTask, urlSession: FileUploadSession = URLSession.shared) {
        self.file = UploadFile(value: file)
        self.file.error = nil
        self.task = task
        self.urlSession = urlSession
        self.result = FileUploadCompletionResult()
    }

    public override func start() {
        assert(!isExecuting, "Operation is already started")

        DDLogInfo("[FileUploader] Job \(file.id) started")
        // Always check for cancellation before launching the task
        if isCancelled {
            DDLogInfo("[FileUploader] Job \(file.id) canceled")
            // Must move the operation to the finished state if it is canceled.
            file.error = .taskCancelled
            end()
            return
        }

        // Start background task
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "File Uploader") {
            DDLogInfo("[FileUploader] Background task expired")
            let rescheduled = BackgroundSessionManager.instance.rescheduleForBackground(task: self.task, fileUrl: self.file.pathURL)
            if rescheduled {
                self.file.error = .taskRescheduled
            } else {
                self.file.sessionUrl = ""
                self.file.error = .taskExpirationCancelled
                UploadQueue.instance.sendPausedNotificationIfNeeded()
            }
            UploadQueue.instance.suspendAllOperations()
            self.task?.cancel()
            self.end()
        }

        getUploadTokenSync()
        getPhAssetIfNeeded()

        // If the operation is not canceled, begin executing the task
        _executing = true
        main()
    }

    public override func main() {
        DDLogInfo("[FileUploader] Executing job \(file.id)")
        guard let token = uploadToken else {
            DDLogInfo("[FileUploader] Failed to fetch upload token for job \(file.id)")
            end()
            return
        }

        let url = URL(string: ApiRoutes.uploadFile(file: file))!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization")

        file.sessionUrl = url.absoluteString
        file.maxRetryCount -= 1

        if let filePath = file.pathURL {
            task = urlSession.uploadTask(with: request, fromFile: filePath, completionHandler: uploadCompletion)
            task?.countOfBytesClientExpectsToSend = file.size + 512 // Extra 512 bytes for request headers
            task?.countOfBytesClientExpectsToReceive = 1024 * 5 // 5KB is a very reasonable upper bound size for a file server response (max observed: 1.47KB)
            progressObservation = task?.progress.observe(\.fractionCompleted, options: .new, changeHandler: { [fileId = file.id] (progress, value) in
                guard let newValue = value.newValue else {
                    return
                }
                UploadQueue.instance.publishProgress(newValue, for: fileId)
            })
            task?.resume()
        } else {
            DDLogInfo("[FileUploader] No file path found for job \(file.id)")
            end()
        }
    }

    public override func cancel() {
        DDLogInfo("[FileUploader] Job \(file.id) canceled")
        super.cancel()
        task?.cancel()
    }

    // MARK: - Private methods

    private func getUploadTokenSync() {
        let syncToken = DispatchGroup()
        syncToken.enter()
        UploadTokenManager.instance.getToken(userId: file.userId, driveId: file.driveId) { (token) in
            self.uploadToken = token
            syncToken.leave()
        }
        syncToken.wait()
    }

    private func getPhAssetIfNeeded() {
        if file.type == .phAsset && file.pathURL == nil {
            DDLogInfo("[FileUploader] Need to fetch photo asset")
            if let asset = file.getPHAsset(),
                let url = PhotoLibraryUploader.instance.getUrlForPHAssetSync(asset) {
                DDLogInfo("[FileUploader] Got photo asset, writing URL")
                file.pathURL = url
            } else {
                DDLogWarn("[FileUploader] Failed to get photo asset")
            }
        }
    }

    public func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        guard file.error != .taskExpirationCancelled && file.error != .taskRescheduled else {
            return
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if let error = error {
            // Client-side error
            DDLogError("[FileUploader] Client-side error for job \(file.id): \(error)")
            if file.error != .taskRescheduled {
                file.sessionUrl = ""
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
            DDLogError("[FileUploader] Job \(file.id) successful")
            file.uploadDate = Date()
            if let drive = AccountManager.instance.getDrive(for: file.userId, driveId: file.driveId),
                let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive) {

                //File is already or has parent in DB let's update it
                BackgroundRealm.getQueue(for: driveFileManager.getRealm().configuration).execute { realm in
                    if driveFileManager.getCachedFile(id: driveFile.id, using: realm) != nil || file.relativePath == "" {
                        let parent = driveFileManager.getCachedFile(id: file.parentDirectoryId, freeze: false, using: realm)
                        try? realm.safeWrite {
                            realm.add(driveFile, update: .all)
                            if file.relativePath == "" && parent != nil && !parent!.children.contains(driveFile) {
                                parent?.children.append(driveFile)
                            }
                        }
                        if let parent = parent {
                            driveFileManager.notifyObserversWith(file: parent)
                        }
                        result.driveFile = driveFile.freeze()
                    }
                }
            }
        } else {
            // Server-side error
            var error = DriveError.serverError
            if let data = data,
                let apiError = try? ApiFetcher.decoder.decode(ApiResponse<EmptyResponse>.self, from: data).error {
                error = DriveError(apiError: apiError)
            }
            DDLogError("[FileUploader] Server error for job \(file.id) (code: \(statusCode)): \(error)")
            file.sessionUrl = ""
            file.error = error
            // If we get an ”object not found“ error, we cancel all further uploads in this folder
            if error == .objectNotFound {
                UploadQueue.instance.cancelAllOperations(withParent: file.parentDirectoryId)
                if PhotoLibraryUploader.instance.isSyncEnabled && PhotoLibraryUploader.instance.settings.parentDirectoryId == file.parentDirectoryId {
                    PhotoLibraryUploader.instance.disableSync()
                }
            }
        }

        end()
    }

    private func end() {
        DDLogError("[FileUploader] Job \(file.id) ended")
        // Save upload file
        result.uploadFile = UploadFile(value: file)
        if file.error != .taskCancelled {
            BackgroundRealm.uploads.execute { uploadsRealm in
                try? uploadsRealm.safeWrite {
                    uploadsRealm.add(UploadFile(value: file), update: .modified)
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
