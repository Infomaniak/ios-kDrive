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
}

public struct UploadCompletionResult {
    var uploadFile: UploadFile!
    var driveFile: File?
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
    @LazyInjectService var freeSpaceService: FreeSpaceService
    
    private var step: UploadOperationStep {
        didSet {
            //UploadOperationLog("~> moved to step:\(step) for: \n \(self.debugDescription)", level: .debug)
        }
    }
    
    override public var debugDescription: String {
        """
        <\(type(of: self)):\(super.debugDescription)
        uploading file id:'\(file.id)'
        backgroundTaskIdentifier:'\(backgroundTaskIdentifier)'
        step: '\(step)'>
        """
    }
    
    public var file: UploadFile
    
    /// Local tracking of running network tasks //// URLSessionUploadTask.id
    var uploadTasks = [String: URLSessionUploadTask]()
    
    private let urlSession: FileUploadSession
    private let itemIdentifier: NSFileProviderItemIdentifier?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    public var result: UploadCompletionResult

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

    public func restore(task: URLSessionUploadTask) {
        if let key = task.currentRequest?.url?.path {
            uploadTasks[key] = task
        }
    }
    
    override public func execute() async {
        step = .startup
        UploadOperationLog("execute \(file.id)")

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

    func enqueueCatching(_ task: @escaping () async throws -> Void) {
        enqueue {
            await self.catching {
                try await task()
            }
        }
    }
    
    /// Upload operation catching handler
    func catching(_ task: @escaping () async throws -> Void) async {
        do {
            try await task()
        }
        
        catch {
            defer {
                UploadOperationLog("catching error:\(file.error) fid:\(file.id)", level: .error)
                synchronousSaveUploadFileToRealm()
                end()
            }
            
            // Not enough space
            if case .notEnoughSpace = error as? FreeSpaceService.StorageIssues {
                self.uploadNotifiable.sendNotEnoughSpaceForUpload(filename: file.name)
                file.maxRetryCount = 0
                file.progress = nil
                file.error = DriveError.errorDeviceStorage.wrapping(error)
                return
            }
            
            // specialized local errors
            if let error = error as? UploadOperation.ErrorDomain {
                switch error {
                case .unableToBuildRequest:
                    file.error = DriveError.localError.wrapping(error)
                    
                case .uploadSessionTaskMissing, .uploadSessionInvalid:
                    cleanUploadFileSession()
                    file.error = DriveError.localError.wrapping(error)

                case .unableToMatchUploadChunk, .splitError, .chunkError, .fileIdentityHasChanged, .parseError, .missingChunkHash:
                    cleanUploadFileSession()
                    file.error = DriveError.localError.wrapping(error)
                }
                
                return
            }
            
            // Other generic DriveError
            file.error = error as? DriveError
            return
        }
    }
    
    // MARK: - Split operations
    
    func storeBackgroundTaskIdentifier() async {
        if !Bundle.main.isExtension {
            backgroundTaskIdentifier = await UIApplication.shared.beginBackgroundTask(withName: "File Uploader",
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
        UploadOperationLog("Asking for an upload Session \(file.id)")

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
                    UploadOperationLog("No remaining chunks to upload at restart, closing session \(self.file.id)")
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
                UploadOperationLog("Unable generate ranges for \(file.id)", level: .error)
                throw ErrorDomain.splitError
            }

            // Get a valid APIV2 UploadSession
            let driveFileManager = try getDriveFileManager()
            let apiFetcher = driveFileManager.apiFetcher
            let drive = driveFileManager.drive
            
            guard let fileSize = fileMetadata.fileSize(url: fileUrl) else {
                UploadOperationLog("Unable to read file size for \(file.id)", level: .error)
                throw DriveError.fileNotFound
            }

            let mebibytes = String(format: "%.2f", BinaryDisplaySize.bytes(fileSize).toMebibytes)
            UploadOperationLog("got fileSize:\(mebibytes)MiB ranges:\(ranges.count) \(file.id)")

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
            uploadProgressable.publishProgress(0, for: file.id)
            synchronousSaveUploadFileToRealm()
            return noProgress
        }
        
        let progress = Double(chunkTasksUploadedCount) / Double(chunkTasksTotalCount)
        
        file.progress = progress
        uploadProgressable.publishProgress(progress, for: file.id)
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
            UploadOperationLog("Unable to get a ChunkProvider for \(file.id)", level: .error)
            throw ErrorDomain.chunkError
        }
        
        UploadOperationLog("Storing Chunk count:\(chunkNumber) of \(chunksToGenerate.count) to write, fid:\(file.id)")
        do {
            try checkFileIdentity(uploadingSession: uploadingSessionTask)
            try checkCancelation()
        
            let sessionToken = uploadingSessionTask.token
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
            
            // Fan-out the chunk we just made
            enqueueCatching {
                try await self.fanOutChunks()
            }
            
            // Chain the next chunk generation if necessary
            UploadOperationLog("chunksToGenerate:\(chunksToGenerate.count) uploadTasks:\(uploadTasks.count) fid:\(file.id)")
            if chunksToGenerate.count > 1 && uploadTasks.count < 5 {
                enqueueCatching {
                    try self.generateChunksAndFanOutIfNeeded()
                }
            }
            
            return true
        } catch {
            UploadOperationLog("Unable to save a chunk to storage. number:\(chunkNumber) error:\(error) for:\(file.id)",
                               level: .error)
            throw error
        }
    }
    
    /// Prepare chunk upload requests, and start them.
    func fanOutChunks() async throws {
        try checkCancelation()
        UploadOperationLog("fanOut for:\(file.id)")

        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        
        let chunksToUpload = uploadingSessionTask.chunkTasks.filter { uploadingChunkTask in
            uploadingChunkTask.canStartUploading == true
        }
        
        UploadOperationLog("fanOut chunksToUpload:\(chunksToUpload.count) for:\(file.id)")
        
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
                
                uploadTasks[chunkPath] = uploadTask
                uploadTask.resume()
            } catch {
                UploadOperationLog("Unable to create an upload request for chunk \(chunkToUpload) error:\(error) - \(file.id)", level: .error)
                file.error = .localError
                end()
                break
            }
        }
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
        file.uploadingSession = nil
        file.progress = nil
        synchronousSaveUploadFileToRealm()
    }
    
    func synchronousSaveUploadFileToRealm() {
        UploadOperationLog("synchronousSaveUploadFileToRealm \(file.id)")
        
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
            UploadOperationLog("getDriveFileManager failed \(file.id)", level: .error)
            throw DriveError.localError
        }
        
        return driveFileManager
    }
    
    /// Throws if the file was modified
    func checkFileIdentity(uploadingSession: UploadingSessionTask) throws {
        guard fileManager.isReadableFile(atPath: uploadingSession.filePath) else {
            UploadOperationLog("File has not a valid readable URL \(String(describing: file.pathURL)) for \(file.id)",
                               level: .error)
            throw DriveError.fileNotFound
        }
        
        guard uploadingSession.fileIdentityHasNotChanged == true else {
            UploadOperationLog("File has changed \(uploadingSession.fileIdentity)≠\(uploadingSession.currentFileIdentity) fid:\(file.id)",
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
            UploadOperationLog("Task is cancelled \(file.id)")
            throw DriveError.taskCancelled
        }
    }
    
    public func retryIfNeeded() {
        // TODO: make sure it works hooking up the sessions again
        enqueueCatching {
            UploadOperationLog("retryIfNeeded fid:\(self.file.id)")
        }
    }
    
    /// Close session if needed.
    func closeSessionAndEnd() async {
        UploadOperationLog("closeSession fid:\(file.id)")
        step = .closeSession
        
        defer {
            end()
        }
        
        guard let uploadSession = file.uploadingSession,
              let uploadSessionToken = uploadSession.uploadSession?.token else {
            UploadOperationLog("No existing session to close fid:\(file.id)")
            return
        }
        
        let driveFileManager: DriveFileManager
        do {
            driveFileManager = try getDriveFileManager()
        } catch {
            UploadOperationLog("Failed to getDriveFileManager fid:\(file.id) userId:\(accountManager.currentUserId)",
                               level: .error)
            file.error = error as? DriveError
            return
        }
        
        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive
        let abstractToken = AbstractTokenWrapper(token: uploadSessionToken)
        
        do {
            let uploadedFile = try await apiFetcher.closeSession(drive: drive, sessionToken: abstractToken)
            let driveFile = uploadedFile.file
            UploadOperationLog("uploadedFile:\(uploadedFile) fid:\(file.id)")
            
            file.uploadDate = Date()
            file.uploadingSession = nil
            file.error = nil
            synchronousSaveUploadFileToRealm()
                        
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
        } catch {
            UploadOperationLog("closeSession error:\(error) fid:\(file.id)",
                               level: .error)
            file.error = error as? DriveError
            synchronousSaveUploadFileToRealm()
        }
    }
    
    // MARK: - Private methods
    
    // MARK: Build request
    
    func buildRequest(chunkNumber: Int64,
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
    
    func storeChunk(_ buffer: Data, number: Int64, fileId: String, sessionToken: String, hash: String) throws -> URL {
        // Create subfolders if needed
        let tempChunkFolder = buildFolderPath(fileId: fileId, sessionToken: sessionToken)
        if fileManager.fileExists(atPath: tempChunkFolder.path, isDirectory: nil) == false {
            try fileManager.createDirectory(at: tempChunkFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Write buffer
        let chunkName = chunkName(number: number, fileId: fileId, hash: hash)
        let chunkPath = tempChunkFolder.appendingPathExtension(chunkName)
        try buffer.write(to: chunkPath, options: [.atomic])
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
    public func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        enqueue(asap: true) {
            let file = self.file
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        
            if let error {
                UploadOperationLog("uploadCompletion KO data:\(data) response:\(response) error:\(error) fid:\(file.id)", level: .error)
            } else {
                UploadOperationLog("uploadCompletion OK data:\(data?.count) fid:\(file.id)")
            }
            
            // Success
            if let data = data,
               error == nil,
               statusCode >= 200, statusCode < 300 /* ::std this ? */ {
                do {
                    try await self.uploadCompletionSuccess(data: data, response: response, error: error)
                } catch {
                    UploadOperationLog("Failed to process chunk upload success. error:\(error) fid:\(file.id)", level: .error)
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
        UploadOperationLog("completion successful \(file.id)")
     
        guard let uploadedChunk = try? ApiFetcher.decoder.decode(ApiResponse<UploadedChunk>.self, from: data).data else {
            UploadOperationLog("parsing error fid:\(file.id)")
            throw ErrorDomain.parseError
        }
        UploadOperationLog("chunk:\(uploadedChunk.number)  fid:\(file.id)")
             
        // update current UploadFile with chunk
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
         
        // Store the chunk object into the correct chunkTask
        if let chunkTask = uploadingSessionTask.chunkTasks.first(where: { $0.chunkNumber == uploadedChunk.number }) {
            chunkTask.chunk = uploadedChunk
             
            // tracking running tasks
            if let path = chunkTask.path {
                uploadTasks.removeValue(forKey: path)
            }
             
            synchronousSaveUploadFileToRealm()
             
            // Some cleanup if we have the chance
            if let path = chunkTask.path {
                let url = URL(fileURLWithPath: path, isDirectory: false)
                DispatchQueue.global(qos: .background).async {
                    UploadOperationLog("cleanup chunk:\(chunkTask.chunkNumber) fid:\(self.file.id)")
                    try? self.fileManager.removeItem(at: url)
                }
            }
        } else {
            UploadOperationLog("matching chunk:\(uploadedChunk.number) failed fid:\(file.id)")
            cleanUploadFileSession()
            throw ErrorDomain.unableToMatchUploadChunk   // TODO: This should trigger a Sentry
        }
         
        // Update UI progress state
        updateUploadProgress()
        
        // Close session and terminate task as the last chunk was uploaded
        let toUploadCount = try chunkTasksToUploadCount()
        if toUploadCount == 0 {
            enqueue {
                UploadOperationLog("No more chunks to be uploaded \(self.file.id)")
                if self.isCancelled == false {
                    await self.closeSessionAndEnd()
                }
            }
        }
        
        // Follow up with chunking again
        else {
            enqueueCatching {
                UploadOperationLog("Remaining \(toUploadCount) chunks to be uploaded \(self.file.id)")
                try self.generateChunksAndFanOutIfNeeded()
            }
        }
    }
    
    private func uploadCompletionLocalFailure(data: Data?, response: URLResponse?, error: Error) {
        UploadOperationLog("completion Client-side error:\(error) fid:\(file.id)", level: .error)
        
        if let data {
            UploadOperationLog("uploadCompletionLocalFailure dataString:\(String(decoding: data, as: UTF8.self)) fid:\(file.id)")
        }
        
        defer {
            self.end()
        }
        
        guard file.error != .taskRescheduled else {
            return
        }

        // store the error
        if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled {
            if file.error != .taskExpirationCancelled && file.error != .taskRescheduled {
                file.error = .taskCancelled
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
            UploadOperationLog("uploadCompletionRemoteFailure dataString:\(String(decoding: data, as: UTF8.self)) fid:\(file.id)")
        }
        
        var error = DriveError.serverError
        if let data = data,
           let apiError = try? ApiFetcher.decoder.decode(ApiResponse<Empty>.self, from: data).error {
            error = DriveError(apiError: apiError)
        }
        
        UploadOperationLog("completion  Server-side error:\(error) fid:\(file.id) ", level: .error)
        
        // Specific Error handling
        switch error {
        case .fileAlreadyExistsError:
            file.maxRetryCount = 0
            file.progress = nil
            
        case .lock:
            // simple retry
            break
        case .notAuthorized, .maintenance:
            // simple retry
            break
            
        case .quotaExceeded:
            file.maxRetryCount = 0
            file.progress = nil
    
        case .uploadDestinationNotFoundError, .uploadDestinationNotWritableError:
            file.maxRetryCount = 0
            file.progress = nil
        
        case .uploadNotTerminatedError, .uploadNotTerminated:
            cleanUploadFileSession()
            
        case .invalidUploadTokenError, .uploadError, .uploadFailedError, .uploadTokenIsNotValid:
            cleanUploadFileSession()
        
        case .objectNotFound:
            // If we get an ”object not found“ error, we cancel all further uploads in this folder
            file.maxRetryCount = 0
            file.progress = nil
            cleanUploadFileSession()
            uploadQueue.cancelAllOperations(withParent: file.parentDirectoryId,
                                            userId: file.userId,
                                            driveId: file.driveId)
                
            if photoLibraryUploader.isSyncEnabled
                && photoLibraryUploader.settings?.parentDirectoryId == file.parentDirectoryId {
                photoLibraryUploader.disableSync()
                NotificationsHelper.sendPhotoSyncErrorNotification()
            }
            
        default:
            // simple retry
            break
        }
        
        file.error = error
    }

    // System notification that we took over 30sec, and should cancel the task.
    private func backgroundTaskExpired() {
        UploadOperationLog("backgroundTaskExpired")
        enqueue(asap: true) {
            UploadOperationLog("backgroundTaskExpired fid:\(self.file.id)")
            let breadcrumb = Breadcrumb(level: .info, category: "BackgroundUploadTask")
            breadcrumb.message = "Rescheduling file \(self.file.name)"
            breadcrumb.data = ["File id": self.file.id,
                               "File name": self.file.name,
                               "File size": self.file.size,
                               "File type": self.file.type.rawValue]
            SentrySDK.addBreadcrumb(crumb: breadcrumb)
            
            // TODO: query BackgroundUploadSessionManager to do this.
            /// Reschedule existing requests to background session
            var buffer = [String: URLSessionUploadTask]()
            for (path, task) in self.uploadTasks {
                task.cancel()
                
                let fileUrl = URL(fileURLWithPath: path, isDirectory: false)
                if let newUploadTask = self.backgroundUploadManager.rescheduleForBackground(task: task,
                                                                                            fileUrl: fileUrl) {
                    buffer[path] = newUploadTask
                }
            }
            self.uploadTasks = buffer
            
            if buffer.isEmpty == false {
                self.file.error = .taskRescheduled
            } else {
                self.file.error = .taskExpirationCancelled
                self.uploadNotifiable.sendPausedNotificationIfNeeded()
            }
            
            self.synchronousSaveUploadFileToRealm()
            
            // all operations should be given the chance to call backgroundTaskExpired
            // self.uploadQueue.suspendAllOperations()
            self.end()
        }
    }

    // did finish in time
    public func end() {
        defer {
            // Terminate the NSOperation
            UploadOperationLog("call finish \(file.id)")
            step = .terminated
            finish()
        }
        
        if let error = file.error {
            UploadOperationLog("end file:\(file.id) errorCode: \(error.code) error:\(error)", level: .error)
        } else {
            UploadOperationLog("end file:\(file.id)")
        }

        if let path = file.pathURL,
           file.shouldRemoveAfterUpload && (file.error == nil || file.error == .taskCancelled) {
            try? fileManager.removeItem(at: path)
        }

        // retry from scratch next time
        if file.maxRetryCount == 0 {
            cleanUploadFileSession()
        }
        
        // If task is cancelled, only reset success
        if file.error == .taskCancelled {
            file.progress = nil
            uploadProgressable.publishProgress(0, for: file.id)
            
//            cleanUploadFileSession()
//            BackgroundRealm.uploads.execute { uploadsRealm in
//                if let toDelete = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: file.id) {
//                    try? uploadsRealm.safeWrite {
//                        uploadsRealm.delete(toDelete)
//                    }
//                }
//            }
        }
        
        // Save upload file
        result.uploadFile = UploadFile(value: file)
        synchronousSaveUploadFileToRealm()
        
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
    }
}
