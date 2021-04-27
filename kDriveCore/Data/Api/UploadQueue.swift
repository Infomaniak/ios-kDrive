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
                let realm = driveFileManager.getRealm()

                //File is already or has parent in DB let's update it
                if driveFileManager.getCachedFile(id: driveFile.id) != nil || file.relativePath == "" {
                    let parent = driveFileManager.getCachedFile(id: file.parentDirectoryId, freeze: false)
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
        autoreleasepool {
            let realm = DriveFileManager.constants.uploadsRealm

            try? realm.safeWrite {
                if file.error == .taskCancelled,
                    let canceledFile = realm.object(ofType: UploadFile.self, forPrimaryKey: file.id) {
                    realm.delete(canceledFile)
                } else {
                    realm.add(UploadFile(value: file), update: .modified)
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

public class UploadQueue {

    public static let instance = UploadQueue()

    public var pausedNotificationSent = false
    public static let uploadQueueIdentifier = "com.infomaniak.background.upload"

    private(set) var operationsInQueue: [String: FileUploader] = [:]
    private(set) lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kDrive upload queue"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    private var realm: Realm {
        return DriveFileManager.constants.uploadsRealm
    }
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
        return Constants.isInExtension ? BackgroundSessionManager.instance : foregroundSession
    }

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
    }

    public func waitForCompletion(_ completionHandler: @escaping () -> (Void)) {
        DispatchQueue.global(qos: .default).async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            completionHandler()
        }
    }

    public func addToQueueFromRealm() {
        DispatchQueue.global(qos: .default).async {
            autoreleasepool {
                self.locks.addToQueueFromRealm.performLocked {
                    let uploadingFiles = self.realm.objects(UploadFile.self).filter("uploadDate = nil AND sessionUrl = \"\" AND maxRetryCount > 0").sorted(byKeyPath: "taskCreationDate")
                    uploadingFiles.forEach { self.addToQueue(file: $0) }
                }
            }
            DispatchQueue.global(qos: .background).async {
                self.cleanupOrphanFiles()
            }
        }
    }

    public func addToQueue(file: UploadFile) {
        locks.addToQueue.performLocked {
            guard !file.isInvalidated && operationsInQueue[file.id] == nil && file.maxRetryCount > 0 else {
                return
            }

            if file.realm == nil {
                try? realm.safeWrite {
                    realm.add(file, update: .modified)
                }
            }

            try? realm.safeWrite {
                file.error = nil
            }

            let operation = FileUploader(file: file, urlSession: bestSession)
            operation.queuePriority = file.priority
            operation.completionBlock = { [parentId = file.parentDirectoryId, fileId = file.id] in
                self.operationsInQueue.removeValue(forKey: fileId)
                self.publishFileUploaded(result: operation.result)
                self.publishUploadCount(withParent: parentId)
            }
            operationQueue.addOperation(operation)
            operationsInQueue[file.id] = operation

            publishUploadCount(withParent: file.parentDirectoryId)
        }
    }

    public func getUploadingFiles(withParent parentId: Int) -> Results<UploadFile> {
        let driveId = AccountManager.instance.currentDriveFileManager.drive.id
        let userId = AccountManager.instance.currentAccount.user.id
        return realm.objects(UploadFile.self).filter(NSPredicate(format: "uploadDate = nil AND parentDirectoryId = %d AND userId = %d AND driveId = %d", parentId, userId, driveId))
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
        operationQueue.operations.filter(\.isExecuting).forEach({ $0.cancel() })
    }

    public func cancel(_ file: UploadFile) {
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
        DispatchQueue.global(qos: .userInteractive).async {
            self.getUploadingFiles(withParent: parentId).forEach { self.cancel($0) }
        }
    }

    public func retry(_ file: UploadFile) {
        try? realm.safeWrite {
            file.error = nil
            file.maxRetryCount = UploadFile.defaultMaxRetryCount
        }
        addToQueue(file: file)
    }

    public func retryAllOperations(withParent parentId: Int) {
        let failedUploadFiles = getUploadingFiles(withParent: parentId).filter("_error != nil")
        failedUploadFiles.forEach { retry($0) }
    }

    public func sendPausedNotificationIfNeeded() {
        if !pausedNotificationSent {
            NotificationsHelper.sendPausedUploadQueueNotification()
            pausedNotificationSent = true
        }
    }

    private func publishUploadCount(withParent parentId: Int) {
        let uploadCount = getUploadingFiles(withParent: parentId).count
        NotificationsHelper.sendUploadQueueNotification(uploadCount: uploadCount, parentId: parentId)
        observations.didChangeUploadCountInParent.values.forEach { closure in
            closure(parentId, uploadCount)
        }
    }

    private func publishFileUploaded(result: FileUploadCompletionResult) {
        observations.didUploadFile.values.forEach { closure in
            closure(result.uploadFile, result.driveFile)
        }
    }

    fileprivate func publishProgress(_ progress: Double, for fileId: String) {
        observations.didChangeProgress.values.forEach { closure in
            closure(fileId, progress)
        }
    }

    private func cleanupOrphanFiles() {
        let importDirectory = DriveFileManager.constants.importDirectoryURL
        let importedFiles = (try? FileManager.default.contentsOfDirectory(atPath: importDirectory.path)) ?? []

        for file in importedFiles {
            let filePath = importDirectory.appendingPathComponent(file, isDirectory: false).path
            if realm.objects(UploadFile.self).filter(NSPredicate(format: "url = %@", filePath)).count == 0 {
                try? FileManager.default.removeItem(atPath: filePath)
            }
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

public protocol FileUploadSession {
    func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask
}

extension URLSession: FileUploadSession { }

public class BackgroundSessionManager: NSObject, URLSessionDataDelegate, FileUploadSession {

    public typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    static let maxBackgroundTasks = 10
    public static var instance = BackgroundSessionManager()

    public var backgroundCompletionHandler: (() -> Void)?
    public var backgroundTaskCount: Int {
        return operations.count
    }

    private var backgroundUploadSession: URLSession!
    private var tasksCompletionHandler: [Int: CompletionHandler] = [:]
    private var tasksData: [Int: Data] = [:]
    private var progressObservers: [Int: NSKeyValueObservation] = [:]
    private var operations = [FileUploader]()

    private override init() {
        super.init()
        let backgroundUrlSessionConfiguration = URLSessionConfiguration.background(withIdentifier: UploadQueue.uploadQueueIdentifier)
        backgroundUrlSessionConfiguration.sessionSendsLaunchEvents = true
        backgroundUrlSessionConfiguration.shouldUseExtendedBackgroundIdleMode = true
        backgroundUrlSessionConfiguration.allowsCellularAccess = true
        backgroundUrlSessionConfiguration.sharedContainerIdentifier = AccountManager.appGroup
        backgroundUrlSessionConfiguration.httpMaximumConnectionsPerHost = 4 // This limit is not really respected because we are using http/2
        backgroundUrlSessionConfiguration.timeoutIntervalForRequest = 60 * 2 // 2 minutes before timeout
        backgroundUrlSessionConfiguration.timeoutIntervalForResource = 60 * 60 * 24 * 3 // 3 days before giving up
        backgroundUrlSessionConfiguration.networkServiceType = .default
        backgroundUploadSession = URLSession(configuration: backgroundUrlSessionConfiguration, delegate: self, delegateQueue: nil)
    }

    public func reconnectBackgroundTasks() {
        backgroundUploadSession.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            for task in uploadTasks {
                if let sessionUrl = task.originalRequest?.url?.absoluteString,
                    let fileId = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
                    .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first?.id {
                    self.progressObservers[task.taskIdentifier] = task.progress.observe(\.fractionCompleted, options: .new, changeHandler: { [fileId = fileId] (progress, value) in
                        guard let newValue = value.newValue else {
                            return
                        }
                        UploadQueue.instance.publishProgress(newValue, for: fileId)
                    })
                }
            }
        }
    }

    public func rescheduleForBackground(task: URLSessionDataTask?, fileUrl: URL?) -> Bool {
        if backgroundTaskCount < BackgroundSessionManager.maxBackgroundTasks,
            let request = task?.originalRequest,
            let fileUrl = fileUrl {
            let task = backgroundUploadSession.uploadTask(with: request, fromFile: fileUrl)
            task.resume()
            DDLogInfo("[BackgroundSession] Rescheduled task \(request.url?.absoluteString ?? "")")
            return true
        } else {
            return false
        }
    }

    public func uploadTask(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping CompletionHandler) -> URLSessionUploadTask {
        let task = backgroundUploadSession.uploadTask(with: request, fromFile: fileURL)
        tasksCompletionHandler[task.taskIdentifier] = completionHandler
        return task
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if tasksData[dataTask.taskIdentifier] != nil {
            tasksData[dataTask.taskIdentifier]!.append(data)
        } else {
            tasksData[dataTask.taskIdentifier] = data
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let task = task as? URLSessionUploadTask {
            getCompletionHandler(for: task)?(tasksData[task.taskIdentifier], task.response, error)
        }
        progressObservers[task.taskIdentifier]?.invalidate()
        progressObservers[task.taskIdentifier] = nil
        tasksData[task.taskIdentifier] = nil
        tasksCompletionHandler[task.taskIdentifier] = nil
    }

    func getCompletionHandler(for task: URLSessionUploadTask) -> CompletionHandler? {
        if let completionHandler = tasksCompletionHandler[task.taskIdentifier] {
            return completionHandler
        } else if let sessionUrl = task.originalRequest?.url?.absoluteString,
            let file = DriveFileManager.constants.uploadsRealm.objects(UploadFile.self)
            .filter(NSPredicate(format: "uploadDate = nil AND sessionUrl = %@", sessionUrl)).first {

            let operation = FileUploader(file: file, task: task, urlSession: self)
            tasksCompletionHandler[task.taskIdentifier] = operation.uploadCompletion
            operations.append(operation)
            return operation.uploadCompletion
        } else {
            return nil
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
