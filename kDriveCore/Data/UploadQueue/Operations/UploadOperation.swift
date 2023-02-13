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
import FileProvider
import Foundation
import InfomaniakCore
import InfomaniakDI
import RealmSwift
import Sentry
import UIKit

/// The current step of the upload with chunks operation
enum UploadOperationStep {
    case `init`
    case initCompletionHandler
    case startup
    case fetchSession
    case chunking
    case chunk(_ index: Int64)
    case schedullingUpload
    case closeSession
    case terminated
    
//    typealias NextStep = (_ curent: UploadOperationStep, _ next: UploadOperationStep)
//    private var nextStep -> NextStep {
//
//    }
//
//    mutating func nextStep() {
//
//    }
}

public struct UploadCompletionResult {
    var uploadFile: UploadFile!
    var driveFile: File?
}

public final class UploadOperation: AsynchronousOperation, UploadOperationable {
    
    enum ErrorDomain: Error {
        case unableToBuildRequest
    }
    
    // MARK: - Attributes

    @LazyInjectService var backgroundUploadManager: BackgroundUploadSessionManager
    @LazyInjectService var uploadQueue: UploadQueueable
    @LazyInjectService var uploadNotifiable: UploadNotifiable
    @LazyInjectService var uploadProgressable: UploadProgressable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var fileManager: FileManagerable
    @LazyInjectService var fileMetadata: FileMetadatable
    
    private var step: UploadOperationStep {
        didSet {
//            UploadOperationLog("~> moved to step:\(step) for: \n \(self.debugDescription)", level: .debug)
            UploadOperationLog("~> moved to step:\(step) for: \n \(self.debugDescription)", level: .debug)
        }
    }
    
    public override var debugDescription: String {
        """
        <\(type(of: self)):\(super.debugDescription)
        uploading file:'\(file)'
        backgroundTaskIdentifier:'\(backgroundTaskIdentifier)'
        step: '\(step)'>
        """
    }
    
    var file: UploadFile
    
    var uploadTasks = [String: URLSessionUploadTask]()
    
    private let urlSession: FileUploadSession
    private let itemIdentifier: NSFileProviderItemIdentifier?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var progressObservation: NSKeyValueObservation?

    public var result: UploadCompletionResult

    private let completionLock = DispatchGroup()
    
    // MARK: - Public methods

    public required init(file: UploadFile,
                         urlSession: FileUploadSession = URLSession.shared,
                         itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        self.file = file.detached()
        self.urlSession = urlSession
        self.itemIdentifier = itemIdentifier
        self.result = UploadCompletionResult()
        self.step = .`init`
    }

    // Restore the operation after BG work
    public required init(file: UploadFile,
                         task: URLSessionUploadTask,
                         urlSession: FileUploadSession = URLSession.shared) {
        file.error = nil
        self.file = file.detached()
        self.urlSession = urlSession
        self.itemIdentifier = nil
        self.result = UploadCompletionResult()
        self.step = .initCompletionHandler
        
        let key = task.currentRequest?.url?.absoluteString ?? UUID().uuidString
        self.uploadTasks[key] = task
    }

    var sessionId: String!
    
    override public func execute() async {
        step = .startup
        UploadOperationLog("execute \(file.id)")
        // Always check for cancellation before launching the task
        do {
            try self.checkCancelation()
        } catch {
            file.error = error as? DriveError
            end()
            return
        }

        // Start background task
        if !Bundle.main.isExtension {
            backgroundTaskIdentifier = await UIApplication.shared.beginBackgroundTask(withName: "File Uploader",
                                                                                      expirationHandler: backgroundTaskExpired)
        }

        // Fetch content from local library if needed
        getPhAssetIfNeeded()
        
        // Setup an uploadingSessionTask within self.file
        do {
            try await getUploadSessionOrCreate()
        } catch {
            file.error = error as? DriveError
            end()
            return
        }
        
        // Gen chunks and shed them as long as we can
        do {
            try await generateChunksAndFanOut()
        } catch {
            file.error = error as? DriveError
            end()
            return
        }
    }

    // MARK: - Split operations
    
    func stopOperationAndReschedule(cleanCache: Bool, error: DriveError) {
        UploadOperationLog("stopOperationAndReschedule cleanCache:\(cleanCache) fid:\(file.id)")
        
        // TODO: reshed
        
        file.error = error
        end()
    }
    
    func generateChunksAndFanOut(maxRecursion: Int = 4) async throws {
        step = .chunking
        
//        var maxRecursion
        
        while try generateNextChunk() { // while has more
            
            // a request callback will resched if needed
//            maxRecursion -=1
//            if maxRecursion <= 0 {
//                break
//            }
            self.step = .schedullingUpload
            try await fanOutChunks() // shedule chunk upload after each generated batch
        }
    }
    
    /// Generate some chunks into a temporary folder from a file
    /// - Parameters:
    /// - Returns: TRUE if this function has generated a chunk to upload and stored it correctly
    func generateNextChunk() throws -> Bool {
        try checkCancelation()
        
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.localError // TODO: Missing session
        }
        
        // Look for the next chunk to generate
        let chunkTask: UploadingChunkTask? = uploadingSessionTask.chunkTasks.first { $0.hasLocalChunk == false }
        guard let chunkTask = chunkTask else {
            return false // We reached the end of the chunks to generate
        }
        let chunkNumber = chunkTask.chunkNumber
        let range = chunkTask.range
        let fileUrl = try getFileUrlIfReadable()
        guard let chunkProvider = ChunkProvider(fileURL: fileUrl, ranges: [range]) else {
            UploadOperationLog("Unable to get a ChunkProvider for \(file.id)", level: .error)
            throw DriveError.localError // TODO: SpecializedError
        }

        guard let chunk = chunkProvider.next() else {
            throw DriveError.localError // TODO: SpecializedError, unable to get data.
        }
        
        UploadOperationLog("Storing Chunk count:\(chunkNumber) \(file.id)")
        step = .chunk(chunkNumber)
        
        do {
            try checkFileIdentity(uploadingSession: uploadingSessionTask)
            
            try checkCancelation()
        
            let sessionToken = uploadingSessionTask.uploadSession!.token // TODO: remove optional Realm asks for
            let chunkSHA256 = chunk.SHA256DigestString
            let chunkPath = try storeChunk(chunk,
                                           number: chunkNumber,
                                           fileId: file.id,
                                           sessionToken: sessionToken,
                                           hash: chunkSHA256)
            UploadOperationLog("chunk stored count:\(chunkNumber) for:\(file.id)")
            
            // set path + sha
            chunkTask.path = chunkPath.path
            chunkTask.sha256 = chunkSHA256
            
            // Save the newly created chunk to the DB
            synchronousSaveUploadFileToRealm()
            return true
        } catch {
            UploadOperationLog("Unable to save a chunk to storage count:\(chunkNumber) error:\(error) for:\(file.id)", level: .error)
            throw error
        }
    }
    
    /// Prepare chunk upload requests, and start them.
    func fanOutChunks() async throws {
        try checkCancelation()
        
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.localError // TODO: Missing session
        }
        
        let chunksToUpload = uploadingSessionTask.chunkTasks.filter { uploadingChunkTask in
            uploadingChunkTask.canStartUploading == true
        }
        UploadOperationLog("fanOut chunksToUpload:\(chunksToUpload) for:\(file.id)")
        
        // schedule all the chunks to be uploaded
        for chunkToUpload in chunksToUpload {
            try checkCancelation()
            
            do {
                guard let chunkPath = chunkToUpload.path else {
                    throw DriveError.localError // TODO: Custom error
                }
                
                let chunkHashHeader = "sha256:\(String(describing: chunkToUpload.sha256))"
                let chunkUrl = URL(fileURLWithPath: chunkPath, isDirectory: false)
                let chunkNumber = chunkToUpload.chunkNumber
                let chunkSize = chunkToUpload.chunkSize
                let request = try buildRequest(chunkNumber: chunkNumber,
                                               chunkSize: chunkSize,
                                               chunkHash: chunkHashHeader,
                                               sessionToken: uploadingSessionTask.uploadSession!.token) // TODO: remove optional Realm asks for
                UploadOperationLog("chunk request:\(request) chunkNumber:\(chunkNumber) chunkUrl:\(chunkUrl) for:\(file.id)")

                chunkToUpload.scheduled = true
                synchronousSaveUploadFileToRealm()
                
                let uploadTask = urlSession.uploadTask(with: request, fromFile: chunkUrl, completionHandler: uploadCompletion)
                // Extra 512 bytes for request headers
                uploadTask.countOfBytesClientExpectsToSend = Int64(chunkSize) + 512
                // 5KB is a very reasonable upper bound size for a file server response (max observed: 1.47KB)
                uploadTask.countOfBytesClientExpectsToReceive = 1024 * 5
                
                // TODO: handle progress observation somewhere over here
                
                uploadTasks[chunkPath] = uploadTask
                uploadTask.resume()
            }
            catch {
                UploadOperationLog("Unable to create an upload request for chunk \(chunkToUpload) error:\(error) - \(file.id)", level: .error)
                file.error = .localError
                end()
                return
                // break ?
            }
        }
        
        // TODO: set observation
//        progressObservation = uploadTask.progress.observe(\.fractionCompleted, options: .new) { [fileId = file.id] _, value in
//            guard let newValue = value.newValue else {
//                return
//            }
//            self.uploadProgressable.publishProgress(newValue, for: fileId)
//        }
//        if let itemIdentifier = itemIdentifier {
//            DriveInfosManager.instance.getFileProviderManager(driveId: file.driveId, userId: file.userId) { manager in
//                manager.register(uploadTask, forItemWithIdentifier: itemIdentifier) { _ in }
//            }
//        }
    }
    
    func getFileUrlIfReadable() throws -> URL {
        guard let fileUrl = file.pathURL,
              fileManager.isReadableFile(atPath: fileUrl.path) else {
            UploadOperationLog("File has not a valid readable URL \(String(describing: file.pathURL)) for \(file.id)",
                               level: .error)
            throw DriveError.fileNotFound
        }
        return fileUrl
    }
    
    func cleanUploadFileSession() {
        UploadOperationLog("Clean uploading session for \(file.id)")
        file.uploadingSession = nil // TODO: Is this the correct thing to do ?
        synchronousSaveUploadFileToRealm()
    }
    
    /// Fetch or create something that represents the state of the upload, and store it to self.file
    func getUploadSessionOrCreate() async throws {
        try checkCancelation()
        step = .fetchSession
        UploadOperationLog("Asking for an upload Session \(file.id)")

        // Decrease retry count
        file.maxRetryCount -= 1

        // Check file is readable
        let fileUrl = try getFileUrlIfReadable()

        // fetch stored session
        if let uploadingSession = file.uploadingSession {
            guard uploadingSession.isExpired == false else {
                cleanUploadFileSession()
                throw DriveError.localError // TODO: specialized error for local session unavaillable
            }
            return // We have a valid upload session
        }
        
        // generate a new session
        else {
            // Compute ranges for a file
            let rangeProvider = RangeProvider(fileURL: fileUrl)
            let ranges: [DataRange]
            do {
                ranges = try rangeProvider.allRanges
            } catch {
                UploadOperationLog("Unable generate ranges for \(file.id)",
                                   level: .error)
                throw DriveError.localError // TODO: specialized error
            }

            // Get a valid APIV2 UploadSession
            let driveFileManager = try getDriveFileManager()
            let apiFetcher = driveFileManager.apiFetcher
            let drive = driveFileManager.drive
            
            guard let fileSize = fileMetadata.fileSize(url: fileUrl) else {
                UploadOperationLog("Unable to read file size for \(file.id)",
                                   level: .error)
                throw DriveError.fileNotFound // TODO: specialized error
            }

            let mebibytes = String(format: "%.2f", BinaryDisplaySize.bytes(fileSize).toMebibytes)
            UploadOperationLog("got fileSize:\(mebibytes)MiB ranges:\(ranges) \(file.id)")

            let session = try await apiFetcher.startSession(drive: drive,
                                                            totalSize: fileSize,
                                                            fileName: file.name,
                                                            totalChunks: ranges.count,
                                                            conflictResolution: .version,
                                                            directoryId: file.parentDirectoryId)
            try checkCancelation()
            
            // Create an uploading session
            let uploadingSessionTask = UploadingSessionTask()

            // The file at the moment we created the UploadingSessionTask
            uploadingSessionTask.filePath = fileUrl.path

            // Wrapping the API response type for Realm
            let dbSession = RUploadSession(uploadSession: session)
            uploadingSessionTask.uploadSession = dbSession

            // Make sure we can track the the file has not changed accross time, while we run the upload session
            let fileIdentity = fileIdentity(fileUrl: fileUrl)
            uploadingSessionTask.fileIdentity = fileIdentity

            // Session expiration date
            let inTwelveHours = Date().addingTimeInterval(12*60*60) // APIV2 upload session runs for 12h
            uploadingSessionTask.sessionExpiration = inTwelveHours

            // Represent the chunks to be uploaded in DB
            // TODO: extend [ranges] type
            for (index, object) in ranges.enumerated() {
                let chunkNumber = Int64(index + 1) // API start at 1
                let chunkTask = UploadingChunkTask(chunkNumber: chunkNumber, range: object)
                uploadingSessionTask.chunkTasks.append(chunkTask)
            }
            
            // All prepared, now we store the upload session in DB before moving on
            self.file.uploadingSession = uploadingSessionTask
            synchronousSaveUploadFileToRealm()
        }
    }
    
    func synchronousSaveUploadFileToRealm(uploadFile: UploadFile? = nil) {
        let fileToUse: UploadFile = uploadFile ?? self.file
        UploadOperationLog("synchronousSaveUploadFileToRealm \(fileToUse.id)")
        
        BackgroundRealm.uploads.execute { uploadsRealm in
            try? uploadsRealm.safeWrite {
                uploadsRealm.add(fileToUse, update: .modified)
                // Keep a 'detached' UploadingFile ivar source of truth
                self.file = fileToUse.detached()
            }
        }
    }
    
    func getDriveFileManager() throws -> DriveFileManager {
        guard let driveFileManager = accountManager.getDriveFileManager(for: accountManager.currentDriveId,
                                                                        userId: accountManager.currentUserId) else {
            UploadOperationLog("Task is cancelled \(file.id)", level: .error)
            throw DriveError.localError
        }
        
        return driveFileManager
    }
    
    /// Throws if the file was modified
    func checkFileIdentity(uploadingSession: UploadingSessionTask) throws {
        let fileUrl = URL(fileURLWithPath: uploadingSession.filePath, isDirectory: false)
        let currentIdentity = fileIdentity(fileUrl: fileUrl)
        guard  uploadingSession.fileIdentity == currentIdentity else {
            UploadOperationLog("File has changed \(uploadingSession.fileIdentity)≠\(currentIdentity) fid:\(file.id)", level: .error)
            // Clean the existing upload session, so we can restart it later
            cleanUploadFileSession()
            throw DriveError.localError // TODO: Specialized error, to maybe resched and clean current session
        }
    }
        
    func fileIdentity(fileUrl :URL) -> String {
        // Make sure we can track the file has not changed accross time, while we run the upload session
        @InjectService var fileMetadata: FileMetadatable
        let fileCreationDate = fileMetadata.fileCreationDate(url: fileUrl)
        let fileModificationDate = fileMetadata.fileModificationDate(url: fileUrl)
        let fileUniqIdentity = "\(String(describing: fileCreationDate))_\(String(describing: fileModificationDate))"
        return fileUniqIdentity
    }
        
    /// Throws if UploadOperation is canceled
    func checkCancelation() throws {
        if isCancelled {
            UploadOperationLog("Task is cancelled \(file.id)")
            throw DriveError.taskCancelled
        }
    }
    
    /// Close session if needed.
    func closeSession() async {
        UploadOperationLog("closeSession fid:\(file.id)")
        
        guard let uploadSessionToken = self.sessionId /*file.uploadingSession?.uploadSession?.token*/ else {
            UploadOperationLog("No existing session to close fid:\(file.id)")
            end()
            return
        }
        
        let driveFileManager: DriveFileManager
        do {
            driveFileManager = try getDriveFileManager()
        } catch {
            UploadOperationLog("Failed to getDriveFileManager fid:\(file.id) userId:\(accountManager.currentUserId)",
                               level: .error)
            file.error = error as? DriveError
            end()
            return
        }
        
        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive
        let abstractToken = AbstractTokenWrapper(token: uploadSessionToken)
        
        do {
            let uploadedFile = try await apiFetcher.closeSession(drive: drive, sessionToken: abstractToken)
            UploadOperationLog("uploadedFile:\(uploadedFile) fid:\(file.id)")
            
            // TODO: Store file to DB
            // and signal upload success / refresh UI
        }
        catch {
            UploadOperationLog("closeSession error:\(error) fid:\(file.id)",
                               level: .error)
        }
        
        end()
    }
    
    // MARK: - Private methods
    
    // MARK: Build request
    
    func buildRequest(chunkNumber: Int64,
                      chunkSize: Int64,
                      chunkHash: String,
                      sessionToken: String) throws -> URLRequest {
        // TODO: Remove accessToken when API updated
        let accessToken = accountManager.currentAccount.token.accessToken
        let headerParameters: [String: String] = ["Authorization": "Bearer \(accessToken)"]
        let headers = HTTPHeaders(headerParameters)
        let route: Endpoint = .appendChunk(drive: AbstractDriveWrapper(id: accountManager.currentDriveId),
                                           sessionToken: AbstractTokenWrapper(token: sessionToken))
        
        guard var urlComponents = URLComponents(url: route.url, resolvingAgainstBaseURL: false) else {
            throw ErrorDomain.unableToBuildRequest
        }
        
        let getParameters = [
            URLQueryItem(name: DriveApiFetcher.APIParameters.chunkNumber.rawValue, value: "\(chunkNumber)"),
            URLQueryItem(name: DriveApiFetcher.APIParameters.chunkSize.rawValue, value: "\(chunkSize)"),
            URLQueryItem(name: DriveApiFetcher.APIParameters.chunkHash.rawValue, value: chunkHash),
        ]
        urlComponents.queryItems = getParameters
        
        guard let url = urlComponents.url else {
            throw ErrorDomain.unableToBuildRequest
        }
        
        return try URLRequest(url: url, method: .post, headers: headers)
    }
    
    // MARK: Chunks
    
    func storeChunk(_ buffer: Data, number: Int64, fileId: String, sessionToken: String, hash: String) throws -> URL {
        // Create subfolders if needed
        let tempChunkFolder = buildFolderPath(fileId: fileId, sessionToken: sessionToken)
        if fileManager.fileExists(atPath: tempChunkFolder.path, isDirectory: nil) == false {
            try fileManager.createDirectory(at: tempChunkFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Write buffer
        let chunkName = chunkName(number: number, fileId: fileId, hash: hash)
        let chunkPath = tempChunkFolder.appendingPathExtension(chunkName)
        try buffer.write(to: chunkPath, options:[.atomic])
        UploadOperationLog("wrote chunk:\(chunkPath) fid:\(file.id)")
        
        return chunkPath
    }
    
    private func buildFolderPath(fileId: String, sessionToken: String) -> URL {
        // NSTemporaryDirectory is perfect for this use case.
        // Cleaned after ≈ 3 days, our session is valid 12h.
        // https://cocoawithlove.com/2009/07/temporary-files-and-folders-in-cocoa.html
        
        let folderUrlString = NSTemporaryDirectory() + "/\(fileId)_\(sessionToken)"
        let folderPath = URL(fileURLWithPath: folderUrlString)
        return folderPath.standardizedFileURL
    }
    
    private func chunkName(number: Int64, fileId: String, hash: String) -> String {
        "upload_\(fileId)_\(hash)_\(number).part"
    }
    
    // MARK: PHAssets
    
    private func getPhAssetIfNeeded() {
        if file.type == .phAsset && file.pathURL == nil {
            UploadOperationLog("Need to fetch photo asset")
            if let asset = file.getPHAsset(),
               let url = photoLibraryUploader.getUrlSync(for: asset) {
                UploadOperationLog("Got photo asset, writing URL")
                file.pathURL = url
            } else {
                UploadOperationLog("Failed to get photo asset", level: .error)
            }
        }
    }

    // MARK: Background callback
    
    // also called on app restoration
    func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        Task {
            try await asyncAwaitQueue.enqueue {
                UploadOperationLog("completionHandler called for \(self.file.id)")
                
                // parse responce and match chunk
                
                // Close session and terminate task if needed
                self.step = .closeSession
                await self.closeSession()
                self.end()
            }
        }
        
        return
        
//        let file = UploadFile(value: file)
//        // Stuff
//        synchronousSaveUploadFileToRealm(uploadFile: file)
//
//        completionLock.wait()
//        // Task has called end() in backgroundTaskExpired
//        guard !isFinished else { return }
//        completionLock.enter()

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        // Client-side error
        if let error = error {
            UploadOperationLog("completion Client-side error:\(error) fid:\(file.id)", level: .error)
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
        }
        
        // Success
        else if let data = data,
                let response = try? ApiFetcher.decoder.decode(ApiResponse<[File]>.self, from: data),
                let driveFile = response.data?.first {
            UploadOperationLog("completion successful \(file.id)")
            
            
            // All chunks uploaded ?
            // NO -> reschedule to finish upload (todo)
            // YES -> reschedule to closeSession()
            
            // Reschedule the upload task
//            let rescheduledSessionId = backgroundUploadManager.rescheduleForBackground(task: nil, fileUrl: file.pathURL)
//            if let sessionId = rescheduledSessionId {
//                file.sessionId = sessionId
//                file.error = .taskRescheduled
//            } else {
//                file.sessionUrl = ""
//                file.error = .taskExpirationCancelled
//                uploadNotifiable.sendPausedNotificationIfNeeded()
//            }
            
            file.uploadDate = Date()
            file.error = nil
            if let driveFileManager = accountManager.getDriveFileManager(for: file.driveId, userId: file.userId) {
                // File is already or has parent in DB let's update it
                let queue = BackgroundRealm.getQueue(for: driveFileManager.realmConfiguration)
                queue.execute { realm in
                    if driveFileManager.getCachedFile(id: driveFile.id, freeze: false, using: realm) != nil || file.relativePath.isEmpty {
                        if let oldFile = realm.object(ofType: File.self, forPrimaryKey: driveFile.id), oldFile.isAvailableOffline {
                            driveFile.isAvailableOffline = true
                        }
                        let parent = driveFileManager.getCachedFile(id: file.parentDirectoryId, freeze: false, using: realm)
                        queue.bufferedWrite(in: parent, file: driveFile)
                        result.driveFile = File(value: driveFile)
                    }
                }
            }
        }
        
        // Server-side error
        else {
            var error = DriveError.serverError
            if let data = data,
               let apiError = try? ApiFetcher.decoder.decode(ApiResponse<Empty>.self, from: data).error {
                error = DriveError(apiError: apiError)
            }
            
            UploadOperationLog("completion  Server-side error:\(error) fid:\(file.id) ", level: .error)
            
            file.sessionUrl = ""
            file.error = error
            if error == .quotaExceeded {
                file.maxRetryCount = 0
            } else if error == .objectNotFound {
                // If we get an ”object not found“ error, we cancel all further uploads in this folder
                file.maxRetryCount = 0
                uploadQueue.cancelAllOperations(withParent: file.parentDirectoryId, userId: file.userId, driveId: file.driveId)
                if photoLibraryUploader.isSyncEnabled && photoLibraryUploader.settings?.parentDirectoryId == file.parentDirectoryId {
                    photoLibraryUploader.disableSync()
                    NotificationsHelper.sendPhotoSyncErrorNotification()
                }
            }
        }

//        end()
//        completionLock.leave()
    }

    // over 30sec
    private func backgroundTaskExpired() {
        self.cancel()
        Task {
            try await asyncAwaitQueue.enqueue {
                UploadOperationLog("backgroundTaskExpired enter\(self.file.id)")
                let breadcrumb = Breadcrumb(level: .info, category: "BackgroundUploadTask")
                breadcrumb.message = "Rescheduling file \(self.file.name)"
                breadcrumb.data = ["File id": self.file.id,
                                   "File name": self.file.name,
                                   "File size": self.file.size,
                                   "File type": self.file.type.rawValue]
                SentrySDK.addBreadcrumb(crumb: breadcrumb)
            }
        }
        
//        completionLock.wait()
//        // Task has called end() in uploadCompletion
//        guard !isFinished else { return }
//        completionLock.enter()

//        UploadOperationLog("backgroundTaskExpired post lock \(file.id)")
//        let breadcrumb = Breadcrumb(level: .info, category: "BackgroundUploadTask")
//        breadcrumb.message = "Rescheduling file \(file.name)"
//        breadcrumb.data = ["File id": file.id,
//                           "File name": file.name,
//                           "File size": file.size,
//                           "File type": file.type.rawValue]
//        SentrySDK.addBreadcrumb(crumb: breadcrumb)
        
        // reschedule
            // is within session upload windows ?
            // ? invalid chunks ?
            // ? retry count ?
        
        
        // TODO: Ouroboros something something…
//        let rescheduledSessionId = backgroundUploadManager.rescheduleForBackground(task: task, fileUrl: file.pathURL)
//        if let sessionId = rescheduledSessionId {
//            file.sessionId = sessionId
//            file.error = .taskRescheduled
//        } else {
//            file.sessionUrl = ""
//            file.error = .taskExpirationCancelled
//            uploadNotifiable.sendPausedNotificationIfNeeded()
//        }
//        uploadQueue.suspendAllOperations()
//
//        // task?.cancel()
//        for (_, value) in uploadTasks {
//            value.cancel()
//        }
//
//        end()
//        UploadOperationLog("backgroundTaskExpired relocking \(file.id)")
//        completionLock.leave()
//        UploadOperationLog("backgroundTaskExpired done \(file.id)")
    }

    // did finish in time
    private func end() {
        if let error = file.error {
            UploadOperationLog("end file:\(file.id) errorCode: \(error.code) error:\(error)", level: .error)
        } else {
            UploadOperationLog("end file:\(file.id)")
        }

        if let path = file.pathURL,
           file.shouldRemoveAfterUpload && (file.error == nil || file.error == .taskCancelled) {
            try? fileManager.removeItem(at: path)
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

        // Terminate the NSOperation
        UploadOperationLog("call finish \(file.id)")
        step = .terminated
        finish()
    }
}
