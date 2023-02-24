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
    case schedulingUpload
    case closeSession
    case terminated
    /// System is canceling the BG task
    case taskExpired
}

public struct UploadCompletionResult {
    var uploadFile: UploadFile?
    var driveFile: File?
}

/// Something that can upload a file.
public protocol UploadOperationable: Operationable {
    
    /// init an UploadOperationable
    /// - Parameters:
    ///   - file: the uploadFile
    ///   - urlSession: the url session to use
    ///   - itemIdentifier: the itemIdentifier
    /// - Throws: if the UploadFile is not there
    init(file: UploadFile,
         urlSession: URLSession,
         itemIdentifier: NSFileProviderItemIdentifier?)
    
    /// We can restore a running session task to an operation
    func restore(task: URLSessionUploadTask, session: URLSession)
    
    /// Network completion handler
    func uploadCompletion(data: Data?, response: URLResponse?, error: Error?)
    
    /// Check if the operation needs to be restarted
    func retryIfNeeded()
    
    /// Process errors and terminate the operation
    func end()
    
    var result: UploadCompletionResult  { get }
    
    var file: UploadFile  { get }
}


public final class UploadOperation: AsynchronousOperation, UploadOperationable {
    
    /// Local specialized errors
    enum ErrorDomain: Error {
        /// Building a request failed
        case unableToBuildRequest
        /// The local upload session is missing
        case uploadSessionTaskMissing
        /// The local upload session is no longer valid
        case uploadSessionInvalid
        /// Unable to match a request callback to a chunk we are trying to upload
        case unableToMatchUploadChunk
        /// Unable to split a file into [ranges]
        case splitError
        /// Unable to split a file into [Data]
        case chunkError
        /// SHA of the file is unavailable at the moment
        case missingChunkHash
        /// The file was modified during the upload task
        case fileIdentityHasChanged
        /// Unable to parse some data
        case parseError
        /// UploadFile is probably deleted in another thread
        case databaseUploadFileNotFound
        
        /// The operation is canceled
        case operationCanceled
        /// The operation is finished
        case operationFinished
    }
    
    // MARK: - Attributes

    @LazyInjectService var backgroundUploadManager: BackgroundUploadSessionManager
    @LazyInjectService var uploadQueue: UploadQueueable
    @LazyInjectService var uploadNotifiable: UploadNotifiable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var fileManager: FileManagerable
    @LazyInjectService var fileMetadata: FileMetadatable
    @LazyInjectService var freeSpaceService: FreeSpaceService
    
    private var step: UploadOperationStep {
        didSet {
            //UploadOperationLog("~> moved to step:\(step) for: \n \(self.debugDescription)", level: .debug)
        }
    }
    
    override public var debugDescription: String {
        """
        <\(type(of: self)):\(super.debugDescription)
        uploading file id:'\(fileId)'
        backgroundTaskIdentifier:'\(backgroundTaskIdentifier)'
        step: '\(step)'>
        """
    }
    
    public let fileId: String
    public var file: UploadFile // TODO: remove
    private var fileObservationToken: NotificationToken?
    
    /// Local tracking of running network tasks
    /// The key used is the and absolute identifier of the task.
    var uploadTasks = [String: URLSessionUploadTask]()
    
    private let urlSession: URLSession
    private let itemIdentifier: NSFileProviderItemIdentifier?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    public var result: UploadCompletionResult

    // MARK: - Public methods

    public required init(file: UploadFile,
                         urlSession: URLSession = URLSession.shared,
                         itemIdentifier: NSFileProviderItemIdentifier? = nil) {
        let detachedFile = file.detached()
        UploadOperationLog("init fid:\(detachedFile.id)")
        self.file = detachedFile
        self.fileId = detachedFile.id
        self.urlSession = urlSession
        self.itemIdentifier = itemIdentifier
        self.result = UploadCompletionResult()
        self.step = .`init`
        
        super.init()
        
        self.observerDeletion()
    }

    public func restore(task: URLSessionUploadTask, session: URLSession) {
        UploadOperationLog("restore")
        enqueue {
            let identifier = session.identifier(for: task)
            UploadOperationLog("restore identifier:\(identifier)")
            self.uploadTasks[identifier] = task
        }
    }
    
    override public func execute() async {
        step = .startup
        UploadOperationLog("execute \(fileId)")

        await catching {
            try self.checkCancelation()
            try self.freeSpaceService.checkEnoughAvailableSpaceForChunkUpload()

            // Fetch a background task identifier
            await self.storeBackgroundTaskIdentifier()

            // Fetch content from local library if needed
            self.getPhAssetIfNeeded()
        
            // Re-Load or Setup an UploadingSessionTask within the UploadingFile
            try await self.getUploadSessionOrCreate()
        
            // Start chunking
            try self.generateChunksAndFanOutIfNeeded()
        }
    }

    // MARK: - Split operations
    
    func storeBackgroundTaskIdentifier() async {
        if !Bundle.main.isExtension {
            backgroundTaskIdentifier = await UIApplication.shared.beginBackgroundTask(withName: "UploadOperation:\(fileId)",
                                                                                      expirationHandler: backgroundTaskExpired)
        }
    }
    
    /// Fetch or create something that represents the state of the upload, and store it to self.file
    func getUploadSessionOrCreate() async throws {
        try checkCancelation()
        
        try freeSpaceService.checkEnoughAvailableSpaceForChunkUpload()
        
        defer {
            updateUploadProgress()
            synchronousSaveUploadFileToRealm()
        }
        
        step = .fetchSession
        UploadOperationLog("Asking for an upload Session \(fileId)")

        // Decrease retry count
        // TODO: Even if BG task is cancelled by system?
        file.maxRetryCount -= 1

        // Check file is readable
        let fileUrl = try getFileUrlIfReadable()

        // fetch stored session
        if let uploadingSession = file.uploadingSession {
            guard uploadingSession.isExpired == false,
                  uploadingSession.fileIdentityHasNotChanged == true else {
                throw ErrorDomain.uploadSessionInvalid
            }
            
            // Cleanup the uploading chunks and session state for re-use
            let chunkTasksToClean = uploadingSession.chunkTasks.filter { $0.doneUploading == false }
            chunkTasksToClean.forEach {
                // clean in order to re-schedule
                
                // TODO: refactor sessionIdentifier + requestUrl handling
                $0.sessionIdentifier = nil
                $0.requestUrl = nil
                $0.path = nil
                $0.sha256 = nil
                $0.error = nil
            }

            // if we have no more chunks to upload, try to close session
            await catching {
                guard let chunkTasksToUploadCount = try? self.chunkTasksToUploadCount() else {
                    return
                }
                      
                // All chunks are uploaded, try to close the session
                if chunkTasksToUploadCount == 0 {
                    UploadOperationLog("No remaining chunks to upload at restart, closing session \(self.fileId)")
                    await self.closeSessionAndEnd()
                }
            }
            
            // We have a valid upload session
        }
        
        // generate a new session
        else {
            // Compute ranges for a file
            let rangeProvider = RangeProvider(fileURL: fileUrl)
            let ranges: [DataRange]
            do {
                ranges = try rangeProvider.allRanges
            } catch {
                UploadOperationLog("Unable generate ranges for \(fileId)", level: .error)
                throw ErrorDomain.splitError
            }

            // Get a valid APIV2 UploadSession
            let driveFileManager = try getDriveFileManager()
            let apiFetcher = driveFileManager.apiFetcher
            let drive = driveFileManager.drive
            
            guard let fileSize = fileMetadata.fileSize(url: fileUrl) else {
                UploadOperationLog("Unable to read file size for \(fileId)", level: .error)
                throw DriveError.fileNotFound
            }

            let mebibytes = String(format: "%.2f", BinaryDisplaySize.bytes(fileSize).toMebibytes)
            UploadOperationLog("got fileSize:\(mebibytes)MiB ranges:\(ranges.count) \(fileId)")

            let session = try await apiFetcher.startSession(drive: drive,
                                                            totalSize: fileSize,
                                                            fileName: file.name,
                                                            totalChunks: ranges.count,
                                                            conflictResolution: file.conflictOption,
                                                            directoryId: file.parentDirectoryId)
            // Create an uploading session
            let uploadingSessionTask = UploadingSessionTask()

            // Store the session token asap as a non null ivar
            uploadingSessionTask.token = session.token
            
            // The file at the moment we created the UploadingSessionTask
            uploadingSessionTask.filePath = fileUrl.path

            // Wrapping the API response type for Realm
            let dbSession = RUploadSession(uploadSession: session)
            uploadingSessionTask.uploadSession = dbSession

            // Make sure we can track the the file has not changed across time, while we run the upload session
            let fileIdentity = fileIdentity(fileUrl: fileUrl)
            uploadingSessionTask.fileIdentity = fileIdentity

            // Session expiration date
            let inElevenHours = Date().addingTimeInterval(11 * 60 * 60) // APIV2 upload session runs for 12h
            uploadingSessionTask.sessionExpiration = inElevenHours

            // Represent the chunks to be uploaded in DB
            for (index, object) in ranges.enumerated() {
                let chunkNumber = Int64(index + 1) // API start at 1
                let chunkTask = UploadingChunkTask(chunkNumber: chunkNumber, range: object)
                uploadingSessionTask.chunkTasks.append(chunkTask)
            }
            
            // All prepared, now we store the upload session in DB before moving on
            file.uploadingSession = uploadingSessionTask
        }
    }

    /// Returns  the upload progress. Ranges from 0 to 1.
    @discardableResult func updateUploadProgress() -> Double {
        // Get the current uploading session
        guard let chunkTasksUploadedCount = try? chunkTasksUploadedCount(),
              let chunkTasksTotalCount = try? chunkTasksTotalCount() else {
            let noProgress: Double = 0
            file.progress = noProgress
            synchronousSaveUploadFileToRealm()
            return noProgress
        }
        
        let progress = Double(chunkTasksUploadedCount) / Double(chunkTasksTotalCount)
        
        file.progress = progress
        synchronousSaveUploadFileToRealm()

        return progress
    }
    
    /// Count of the chunks to upload, independent of chunk produced on local storage
    func chunkTasksToUploadCount() throws -> Int {
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        let filteredTasks = uploadingSessionTask.chunkTasks.filter { $0.doneUploading == false }
        return filteredTasks.count
    }
    
    /// Count of the uploaded chunks to upload, independent of chunk produced on local storage
    func chunkTasksUploadedCount() throws -> Int {
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        let filteredTasks = uploadingSessionTask.chunkTasks.filter { $0.doneUploading == true }
        return filteredTasks.count
    }
    
    /// How many chunk requests are active at the moment
    func chunkTasksUploadingCount() throws -> Int {
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        let filteredTasks = uploadingSessionTask.chunkTasks.filter { $0.scheduled == true }
        return filteredTasks.count
    }
    
    /// Count of the chunks to upload, independent of chunk produced on local storage
    func chunkTasksTotalCount() throws -> Int {
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        return uploadingSessionTask.chunkTasks.count
    }
    
    /// Generate some chunks into a temporary folder from a file
    /// - Parameters:
    /// - Returns: TRUE if this function has generated a chunk to upload and stored it correctly
    @discardableResult
    func generateChunksAndFanOutIfNeeded() throws -> Bool {
        try checkCancelation()
        
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        try checkFileIdentity(uploadingSession: uploadingSessionTask)
        
        // Look for the next chunk to generate
        let chunksToGenerate = uploadingSessionTask.chunkTasks.filter { $0.doneUploading == false && $0.hasLocalChunk == false }
        guard let chunkTask = chunksToGenerate.first else {
            return false // No more chunks to generate
        }
        
        let chunkNumber = chunkTask.chunkNumber
        step = .chunk(chunkNumber)
        let range = chunkTask.range
        let fileUrl = try getFileUrlIfReadable()
        guard let chunkProvider = ChunkProvider(fileURL: fileUrl, ranges: [range]),
              let chunk = chunkProvider.next() else {
            UploadOperationLog("Unable to get a ChunkProvider for \(fileId)", level: .error)
            throw ErrorDomain.chunkError
        }
        
        UploadOperationLog("Storing Chunk count:\(chunkNumber) of \(chunksToGenerate.count) to write, fid:\(fileId)")
        do {
            try checkFileIdentity(uploadingSession: uploadingSessionTask)
            try checkCancelation()
        
            let sessionToken = uploadingSessionTask.token
            let chunkSHA256 = chunk.SHA256DigestString
            let chunkPath = try storeChunk(chunk,
                                           number: chunkNumber,
                                           fileId: fileId,
                                           sessionToken: sessionToken,
                                           hash: chunkSHA256)
            UploadOperationLog("chunk stored count:\(chunkNumber) for:\(fileId)")
            
            // set path + sha
            chunkTask.path = chunkPath.path
            chunkTask.sha256 = chunkSHA256
            
            // Save the newly created chunk to the DB
            synchronousSaveUploadFileToRealm()
            
            // Fan-out the chunk we just made
            enqueueCatching {
                try await self.fanOutChunks()
            }
            
            // Chain the next chunk generation if necessary
            UploadOperationLog("chunksToGenerate:\(chunksToGenerate.count) uploadTasks:\(uploadTasks.count) fid:\(fileId)")
            if chunksToGenerate.count > 1 && uploadTasks.count < 5 {
                enqueueCatching {
                    try self.generateChunksAndFanOutIfNeeded()
                }
            }
            
            return true
        } catch {
            UploadOperationLog("Unable to save a chunk to storage. number:\(chunkNumber) error:\(error) for:\(fileId)",
                               level: .error)
            throw error
        }
    }
    
    /// Prepare chunk upload requests, and start them.
    func fanOutChunks() async throws {
        try checkCancelation()
        UploadOperationLog("fanOut for:\(fileId)")

        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        let chunksToUpload = uploadingSessionTask.chunkTasks.filter { uploadingChunkTask in
            uploadingChunkTask.canStartUploading == true
        }
        
        UploadOperationLog("fanOut chunksToUpload:\(chunksToUpload.count) for:\(fileId)")
        
        // Schedule all the chunks to be uploaded
        for chunkToUpload in chunksToUpload {
            try checkCancelation()
            
            do {
                guard let chunkPath = chunkToUpload.path,
                      let sha256 = chunkToUpload.sha256 else {
                    throw ErrorDomain.missingChunkHash
                }
                
                let chunkHashHeader = "sha256:\(sha256)"
                let chunkUrl = URL(fileURLWithPath: chunkPath, isDirectory: false)
                let chunkNumber = chunkToUpload.chunkNumber
                let chunkSize = chunkToUpload.chunkSize
                let request = try buildRequest(chunkNumber: chunkNumber,
                                               chunkSize: chunkSize,
                                               chunkHash: chunkHashHeader,
                                               sessionToken: uploadingSessionTask.token)
                let uploadTask = urlSession.uploadTask(with: request, fromFile: chunkUrl, completionHandler: uploadCompletion)
                // Extra 512 bytes for request headers
                uploadTask.countOfBytesClientExpectsToSend = Int64(chunkSize) + 512
                // 5KB is a very reasonable upper bound size for a file server response (max observed: 1.47KB)
                uploadTask.countOfBytesClientExpectsToReceive = 1024 * 5
                
                chunkToUpload.sessionIdentifier = urlSession.identifier
                chunkToUpload.requestUrl = request.url?.absoluteString
                synchronousSaveUploadFileToRealm()
                
                let identifier = urlSession.identifier(for: uploadTask)
                uploadTasks[identifier] = uploadTask
                uploadTask.resume()
                
                UploadOperationLog("started task identifier:\(identifier) for:\(fileId)")

            } catch {
                UploadOperationLog("Unable to create an upload request for chunk \(chunkToUpload) error:\(error) - \(fileId)", level: .error)
                file.error = .localError
                end()
                break
            }
        }
    }
    
    func getFileUrlIfReadable() throws -> URL {
        guard let fileUrl = file.pathURL,
              fileManager.isReadableFile(atPath: fileUrl.path) else {
            UploadOperationLog("File has not a valid readable URL \(String(describing: file.pathURL)) for \(fileId)",
                               level: .error)
            throw DriveError.fileNotFound
        }
        return fileUrl
    }
    
    func cleanUploadFileSession() {
        UploadOperationLog("Clean uploading session for \(fileId)")
        file.uploadingSession = nil
        file.progress = nil
        synchronousSaveUploadFileToRealm()
    }
    
    func synchronousSaveUploadFileToRealm(function: StaticString = #function) {
        UploadOperationLog("synchronousSaveUploadFileToRealm \(fileId) in:\(function)")
        guard file.error != DriveError.taskCancelled else {
            return
        }
        
        BackgroundRealm.uploads.execute { uploadsRealm in
            try? uploadsRealm.safeWrite {
                let fileCopy = file.detached() /// We save a copy so the .file ivar is never attached to a realm
                uploadsRealm.add(fileCopy, update: .modified)
            }
        }
    }
    
    func getDriveFileManager() throws -> DriveFileManager {
        guard let driveFileManager = accountManager.getDriveFileManager(for: accountManager.currentDriveId,
                                                                        userId: accountManager.currentUserId) else {
            UploadOperationLog("getDriveFileManager failed \(fileId)", level: .error)
            throw DriveError.localError
        }
        
        return driveFileManager
    }
    
    /// Throws if the file was modified
    func checkFileIdentity(uploadingSession: UploadingSessionTask) throws {
        guard fileManager.isReadableFile(atPath: uploadingSession.filePath) else {
            UploadOperationLog("File has not a valid readable URL \(String(describing: file.pathURL)) for \(fileId)",
                               level: .error)
            throw DriveError.fileNotFound
        }
        
        guard uploadingSession.fileIdentityHasNotChanged == true else {
            UploadOperationLog("File has changed \(uploadingSession.fileIdentity)≠\(uploadingSession.currentFileIdentity) fid:\(fileId)",
                               level: .error)
            throw ErrorDomain.fileIdentityHasChanged
        }
    }
        
    func fileIdentity(fileUrl: URL) -> String {
        // Make sure we can track the file has not changed across time, while we run the upload session
        @InjectService var fileMetadata: FileMetadatable
        let fileCreationDate = fileMetadata.fileCreationDate(url: fileUrl)
        let fileModificationDate = fileMetadata.fileModificationDate(url: fileUrl)
        let fileUniqIdentity = "\(String(describing: fileCreationDate))_\(String(describing: fileModificationDate))"
        return fileUniqIdentity
    }
        
    /// Throws if UploadOperation is canceled
    func checkCancelation() throws {
        if isCancelled {
            UploadOperationLog("Task is cancelled \(fileId)")
            throw ErrorDomain.operationCanceled
        }
        
        else if isFinished {
            UploadOperationLog("Task is isFinished \(fileId)")
            throw ErrorDomain.operationFinished
        }
    }
    
    public func retryIfNeeded() {
        UploadOperationLog("retryIfNeeded fid:\(self.fileId)")
        // TODO: make sure it works hooking up the sessions again
        enqueueCatching {
            await self.execute()
        }
    }
    
    /// Close session if needed.
    func closeSessionAndEnd() async {
        UploadOperationLog("closeSession fid:\(fileId)")
        step = .closeSession
        
        defer {
            synchronousSaveUploadFileToRealm()
            end()
        }
        
        guard let uploadSession = file.uploadingSession,
              let uploadSessionToken = uploadSession.uploadSession?.token else {
            UploadOperationLog("No existing session to close fid:\(fileId)")
            return
        }
        
        let driveFileManager: DriveFileManager
        do {
            driveFileManager = try getDriveFileManager()
        } catch {
            UploadOperationLog("Failed to getDriveFileManager fid:\(fileId) userId:\(accountManager.currentUserId)",
                               level: .error)
            file.error = error as? DriveError
            return
        }
        
        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive
        let abstractToken = AbstractTokenWrapper(token: uploadSessionToken)
        
        await catching {
            let uploadedFile = try await apiFetcher.closeSession(drive: drive, sessionToken: abstractToken)
            let driveFile = uploadedFile.file
            UploadOperationLog("uploadedFile 'File' id:\(uploadedFile.file.id) fid:\(self.fileId)")
            
            self.file.uploadDate = Date()
            self.file.uploadingSession = nil
            self.file.error = nil
                        
            if let driveFileManager = self.accountManager.getDriveFileManager(for: self.file.driveId, userId: self.file.userId) {
                // File is already or has parent in DB let's update it
                let queue = BackgroundRealm.getQueue(for: driveFileManager.realmConfiguration)
                queue.execute { realm in
                    if driveFileManager.getCachedFile(id: driveFile.id, freeze: false, using: realm) != nil || self.file.relativePath.isEmpty {
                        if let oldFile = realm.object(ofType: File.self, forPrimaryKey: driveFile.id), oldFile.isAvailableOffline {
                            driveFile.isAvailableOffline = true
                        }
                        let parent = driveFileManager.getCachedFile(id: self.file.parentDirectoryId, freeze: false, using: realm)
                        queue.bufferedWrite(in: parent, file: driveFile)
                        self.result.driveFile = File(value: driveFile)
                    }
                }
            }
        }
    }
    
    // MARK: - Private methods
    
    /// listen to deletion events
    private func observerDeletion() {
        UploadOperationLog("observerDeletion")
        var token: NotificationToken?
        BackgroundRealm.uploads.execute { uploadsRealm in
            guard let uploadFile = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.fileId) else {
                return
            }
            
            token = uploadFile.observe { change in
                switch change {
                case .deleted:
                    UploadOperationLog("The source UploadFile was deleted.")
                    self.cancel()
                default:
                    break
                }
            }
        }
        
        self.fileObservationToken = token
    }
    
    // MARK: Build request
    
    private func buildRequest(chunkNumber: Int64,
                              chunkSize: Int64,
                              chunkHash: String,
                              sessionToken: String) throws -> URLRequest {
        // TODO: Remove accessToken when API updated
        let accessToken = accountManager.currentAccount.token.accessToken
        let headerParameters = ["Authorization": "Bearer \(accessToken)"]
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
    
    private func storeChunk(_ buffer: Data, number: Int64, fileId: String, sessionToken: String, hash: String) throws -> URL {
        // Create subfolders if needed
        let tempChunkFolder = buildFolderPath(fileId: fileId, sessionToken: sessionToken)
        UploadOperationLog("using chunk folder:'\(tempChunkFolder)' fid:\(fileId)")
        if fileManager.fileExists(atPath: tempChunkFolder.path, isDirectory: nil) == false {
            try fileManager.createDirectory(at: tempChunkFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Write buffer
        let chunkName = chunkName(number: number, fileId: fileId, hash: hash)
        let chunkPath = tempChunkFolder.appendingPathExtension(chunkName)
        try buffer.write(to: chunkPath, options: [.atomic])
        UploadOperationLog("wrote chunk:\(chunkPath) fid:\(fileId)")
        
        return chunkPath
    }
    
    private func buildFolderPath(fileId: String, sessionToken: String) -> URL {
        // NSTemporaryDirectory is perfect for this use case.
        // Cleaned after ≈ 3 days, our session is valid 12h.
        // https://cocoawithlove.com/2009/07/temporary-files-and-folders-in-cocoa.html
        
        // fileId and sessionToken can break the URL path, hashing makes sure it works
        let folderUrlString = NSTemporaryDirectory() + "/\(fileId.SHA256DigestString)_\(sessionToken.SHA256DigestString)"
        let folderPath = URL(fileURLWithPath: folderUrlString)
        return folderPath.standardizedFileURL
    }
    
    private func chunkName(number: Int64, fileId: String, hash: String) -> String {
        // Hashing name as it can break path building. Also it keeps it short
        let fileName = "upload_\(fileId)_\(hash)_\(number)".SHA256DigestString
        return fileName + ".part"
    }
    
    // MARK: PHAssets
    
    private func getPhAssetIfNeeded() {
        UploadOperationLog("getPhAssetIfNeeded type:\(file.type)")
        if file.type == .phAsset /*&& file.pathURL == nil*/ {
            UploadOperationLog("Need to fetch photo asset")
            if let asset = file.getPHAsset(),
               let url = photoLibraryUploader.getUrlSync(for: asset) {
                UploadOperationLog("Got photo asset, writing URL \(url)")
                file.pathURL = url
                file.uploadingSession?.filePath = url.path
            } else {
                UploadOperationLog("Failed to get photo asset", level: .error)
            }
        }
    }

    // MARK: Background callback
    
    // also called on app restoration
    public func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        enqueue(asap: true) {
            let file = self.file
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        
            if let error {
                UploadOperationLog("uploadCompletion KO data:\(data) response:\(response) error:\(error) fid:\(self.fileId)", level: .error)
            } else {
                UploadOperationLog("uploadCompletion OK data:\(data?.count) fid:\(self.fileId)")
            }
            
            // Success
            if let data = data,
               error == nil,
               statusCode >= 200, statusCode < 300 {
                do {
                    try await self.uploadCompletionSuccess(data: data, response: response, error: error)
                } catch {
                    UploadOperationLog("Failed to process chunk upload success. error:\(error) fid:\(self.fileId)", level: .error)
                    self.cleanUploadFileSession()
                    self.end()
                }
            }
        
            // Client-side error
            else if let error = error {
                self.uploadCompletionLocalFailure(data: data, response: response, error: error)
            }
        
            // Server-side error
            else {
                self.uploadCompletionRemoteFailure(data: data, response: response, error: error)
            }
        }
    }
    
    private func uploadCompletionSuccess(data: Data, response: URLResponse?, error: Error?) async throws {
        UploadOperationLog("completion successful \(fileId)")
     
        guard let uploadedChunk = try? ApiFetcher.decoder.decode(ApiResponse<UploadedChunk>.self, from: data).data else {
            UploadOperationLog("parsing error fid:\(fileId)")
            throw ErrorDomain.parseError
        }
        UploadOperationLog("chunk:\(uploadedChunk.number)  fid:\(fileId)")
             
        // update current UploadFile with chunk
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
         
        // Store the chunk object into the correct chunkTask
        if let chunkTask = uploadingSessionTask.chunkTasks.first(where: { $0.chunkNumber == uploadedChunk.number }) {
            chunkTask.chunk = uploadedChunk
             
            // tracking running tasks
            if let identifier = chunkTask.taskIdentifier {
                uploadTasks.removeValue(forKey: identifier)
                chunkTask.taskIdentifier = nil
            }
            
            synchronousSaveUploadFileToRealm()
             
            // Some cleanup if we have the chance
            if let path = chunkTask.path {
                let url = URL(fileURLWithPath: path, isDirectory: false)
                DispatchQueue.global(qos: .background).async {
                    UploadOperationLog("cleanup chunk:\(chunkTask.chunkNumber) fid:\(self.fileId)")
                    try? self.fileManager.removeItem(at: url)
                }
            }
        } else {
            UploadOperationLog("matching chunk:\(uploadedChunk.number) failed fid:\(fileId)")
            cleanUploadFileSession()
            throw ErrorDomain.unableToMatchUploadChunk   // TODO: This should trigger a Sentry
        }
         
        // Update UI progress state
        updateUploadProgress()
        
        // Close session and terminate task as the last chunk was uploaded
        let toUploadCount = try chunkTasksToUploadCount()
        if toUploadCount == 0 {
            enqueue {
                UploadOperationLog("No more chunks to be uploaded \(self.fileId)")
                if self.isCancelled == false {
                    await self.closeSessionAndEnd()
                }
            }
        }
        
        // Follow up with chunking again
        else {
            enqueueCatching {
                UploadOperationLog("Remaining \(toUploadCount) chunks to be uploaded \(self.fileId)")
                try self.generateChunksAndFanOutIfNeeded()
            }
        }
    }
    
    private func uploadCompletionLocalFailure(data: Data?, response: URLResponse?, error: Error) {
        UploadOperationLog("completion Client-side error:\(error) fid:\(fileId)", level: .error)
        
        if let data {
            // TODO: expected behaviour ?
            UploadOperationLog("uploadCompletionLocalFailure dataString:\(String(decoding: data, as: UTF8.self)) fid:\(fileId)")
        }
        
        defer {
            self.end()
        }
        
        guard file.error != .taskRescheduled || file.error != .taskPaused else {
            return
        }

        // save the error
        if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
            if file.error != .taskExpirationCancelled && file.error != .taskRescheduled && file.error != .taskPaused {
                file.error = DriveError.taskCancelled
                file.maxRetryCount = 0
                file.progress = nil
            }
        } else {
            file.error = .networkError
        }
        
        synchronousSaveUploadFileToRealm()
    }
    
    private func uploadCompletionRemoteFailure(data: Data?, response: URLResponse?, error: Error?) {
        defer {
            self.synchronousSaveUploadFileToRealm()
            self.end()
        }
        
        if let data {
            UploadOperationLog("uploadCompletionRemoteFailure dataString:\(String(decoding: data, as: UTF8.self)) fid:\(fileId)")
        }
        
        var error = DriveError.serverError
        if let data = data,
           let apiError = try? ApiFetcher.decoder.decode(ApiResponse<Empty>.self, from: data).error {
            error = DriveError(apiError: apiError)
        }
        
        UploadOperationLog("completion  Server-side error:\(error) fid:\(fileId) ", level: .error)
        handleRemoteErrors(error: error)
    }

    
    /// UIKit needs the function to return after the task is stoped to not print an error
    private let expirationLock = DispatchGroup()

    // System notification that we took over 30sec, and should cancel the task.
    private func backgroundTaskExpired() {
        UploadOperationLog("backgroundTaskExpired")
        step = .taskExpired
        expirationLock.enter()
        enqueue(asap: true) {
            UploadOperationLog("backgroundTaskExpired fid:\(self.fileId)")
            let breadcrumb = Breadcrumb(level: .info, category: "BackgroundUploadTask")
            breadcrumb.message = "Rescheduling file \(self.file.name)"
            breadcrumb.data = ["File id": self.fileId,
                               "File name": self.file.name,
                               "File size": self.file.size,
                               "File type": self.file.type.rawValue]
            SentrySDK.addBreadcrumb(crumb: breadcrumb)
            
            let tasks: [UploadingChunkTask]
            if let uploadingSession = self.file.uploadingSession {
                tasks = Array(uploadingSession.chunkTasks)
            } else {
                tasks = []
            }
            
            /// Reschedule existing requests to background session
            var didReschedule = false
            for (identifier, task) in self.uploadTasks {
                defer {
                    task.cancel()
                }
                
                // Match existing UploadingChunkTask with a TaskIdentifier to be updated
                guard let chunkTask = tasks.first(where: { $0.taskIdentifier == identifier }),
                      let path = chunkTask.path else {
                    return
                }
                
                let fileUrl = URL(fileURLWithPath: path, isDirectory: false)
                let identifier = self.backgroundUploadManager.rescheduleForBackground(task: task, fileUrl: fileUrl)
                
                chunkTask.taskIdentifier = identifier
                didReschedule = true
            }
            
            if didReschedule == true {
                self.file.error = .taskRescheduled
            } else {
                self.file.error = .taskExpirationCancelled
                self.uploadNotifiable.sendPausedNotificationIfNeeded()
            }
            
            self.synchronousSaveUploadFileToRealm()
            
            // all operations should be given the chance to call backgroundTaskExpired
            // self.uploadQueue.suspendAllOperations()
            self.end()
            self.expirationLock.leave()
        }
        expirationLock.wait()
    }

    // did finish in time
    public func end() {
        // Prevent duplicate call, as end() finishes the operation
        guard isFinished == false else {
            UploadOperationLog("dupe finish \(fileId)")
            return
        }
        
        defer {
            // Terminate the NSOperation
            UploadOperationLog("call finish \(fileId)")
            
            // Make sure we call endBackgroundTask at the end of the operation
            if backgroundTaskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
            
            step = .terminated
            finish()
        }
        
        if let error = file.error {
            UploadOperationLog("end file:\(fileId) errorCode: \(error.code) error:\(error)", level: .error)
        } else {
            UploadOperationLog("end file:\(fileId)")
        }

        if let path = file.pathURL,
           file.shouldRemoveAfterUpload && (file.error == nil || file.error == .taskCancelled) {
            try? fileManager.removeItem(at: path)
        }

        // retry from scratch next time
        if file.maxRetryCount == 0 {
            cleanUploadFileSession()
        }
        
        // If task is cancelled, remove it from list
        if file.error == DriveError.taskCancelled {
            UploadOperationLog("Delete file:\(fileId)")
            // Delete UploadFile entry is canceled by the user
            BackgroundRealm.uploads.execute { uploadsRealm in
                if let toDelete = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.fileId) {
                    try? uploadsRealm.safeWrite {
                        uploadsRealm.delete(toDelete)
                    }
                }
            }
        }
        // otherwise only reset success
        else {
            file.progress = nil
            
            // Save upload file
            result.uploadFile = UploadFile(value: file)
            synchronousSaveUploadFileToRealm()
        }
    }
}
