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
    
    var file: UploadFile
    
    // TODO: I'd like to move it to BGUploadManager. Not the job imo of the upload operation.
    /// Local tracking of running tasks
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
        
        if let key = task.currentRequest?.url?.path {
            uploadTasks[key] = task
        }
    }
    
    override public func execute() async {
        step = .startup
        UploadOperationLog("execute \(file.id)")
        // Always check for cancellation before launching the task
        do {
            try checkCancelation()
        } catch {
            file.error = error as? DriveError
            end()
            return
        }

        // Fetch a background task identifier
        await storeBackgroundTaskIdentifier()

        // Fetch content from local library if needed
        getPhAssetIfNeeded()
        
        // Re-Load or Setup an UploadingSessionTask within the UploadingFile
        do {
            try await getUploadSessionOrCreate()
        } catch {
            file.error = error as? DriveError
            end()
            return
        }
        
        // Start chunking
        do {
            try generateChunksAndFanOutIfNeeded()
        } catch {
            file.error = error as? DriveError
            end()
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
        
        defer {
            let progress = uploadProgress()
            uploadProgressable.publishProgress(progress, for: file.id)
            synchronousSaveUploadFileToRealm()
        }
        
        step = .fetchSession
        UploadOperationLog("Asking for an upload Session \(file.id)")

        // Decrease retry count
        file.maxRetryCount -= 1

        // Check file is readable
        let fileUrl = try getFileUrlIfReadable()

        // fetch stored session
        if let uploadingSession = file.uploadingSession {
            guard uploadingSession.isExpired == false,
                  uploadingSession.fileIdentityHasNotChanged == true else {
                cleanUploadFileSession()
                throw DriveError.uploadSessionInvalid
            }
            
            // Cleanup the uploading chunks and session state for re-use
            let chunkTasksToClean = uploadingSession.chunkTasks.filter { $0.doneUploading == false }
            chunkTasksToClean.forEach {
                // clean in order to re-schedule
                $0.sessionIdentifier = nil
                $0.requestUrl = nil
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
                throw DriveError.splitError
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

            // Store the session token asap as a nonnull ivar
            uploadingSessionTask.token = session.token
            
            // The file at the moment we created the UploadingSessionTask
            uploadingSessionTask.filePath = fileUrl.path

            // Wrapping the API response type for Realm
            let dbSession = RUploadSession(uploadSession: session)
            uploadingSessionTask.uploadSession = dbSession

            // Make sure we can track the the file has not changed accross time, while we run the upload session
            let fileIdentity = fileIdentity(fileUrl: fileUrl)
            uploadingSessionTask.fileIdentity = fileIdentity

            // Session expiration date
            let inTwelveHours = Date().addingTimeInterval(11 * 60 * 60) // APIV2 upload session runs for 12h
            uploadingSessionTask.sessionExpiration = inTwelveHours

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
    func uploadProgress() -> Double {
        // Get the current uploading session
        guard let chunkTasksUploadedCount = try? chunkTasksUploadedCount(),
              let chunkTasksTotalCount = try? chunkTasksTotalCount() else {
            return 0
        }
        
        return Double(chunkTasksUploadedCount) / Double(chunkTasksTotalCount)
    }
    
    /// Count of the chunks to upload, independent of chunk produced on local storage
    func chunkTasksToUploadCount() throws -> Int {
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.uploadSessionTaskMissing
        }
        
        let filteredTasks = uploadingSessionTask.chunkTasks.filter { $0.doneUploading == false }
        return filteredTasks.count
    }
    
    /// Count of the uploaded chunks to upload, independent of chunk produced on local storage
    func chunkTasksUploadedCount() throws -> Int {
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.uploadSessionTaskMissing
        }
        
        let filteredTasks = uploadingSessionTask.chunkTasks.filter { $0.doneUploading == true }
        return filteredTasks.count
    }
    
    /// How many chunk requests are active at the moment
    func chunkTasksUploadingCount() throws -> Int {
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.uploadSessionTaskMissing
        }
        
        let filteredTasks = uploadingSessionTask.chunkTasks.filter { $0.scheduled == true }
        return filteredTasks.count
    }
    
    /// Count of the chunks to upload, independent of chunk produced on local storage
    func chunkTasksTotalCount() throws -> Int {
        // Get the current uploading session
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.uploadSessionTaskMissing
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
            throw DriveError.uploadSessionTaskMissing
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
            throw DriveError.chunkError
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
            enqueue {
                try? await self.fanOutChunks()
            }
            
            // Chain the next chunk generation if necessary
            UploadOperationLog("chunksToGenerate:\(chunksToGenerate.count) uploadTasks:\(uploadTasks.count) fid:\(file.id)")
            if chunksToGenerate.count > 1 && uploadTasks.count < 5 {
                enqueue {
                    _ = try? self.generateChunksAndFanOutIfNeeded()
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
            throw DriveError.uploadSessionTaskMissing
        }
        
        let chunksToUpload = uploadingSessionTask.chunkTasks.filter { uploadingChunkTask in
            uploadingChunkTask.canStartUploading == true
        }
        
        // No more chunks to upload
        guard chunksToUpload.isEmpty == false else {
            enqueue {
                // All chunks are uploaded, try to close the session
                guard self.uploadProgress() == 1 else {
                    return
                }
                await self.closeSessionAndEnd()
            }
            return
        }
        
        UploadOperationLog("fanOut chunksToUpload:\(chunksToUpload.count) for:\(file.id)")
        
        // Schedule all the chunks to be uploaded
        for chunkToUpload in chunksToUpload {
            try checkCancelation()
            
            do {
                guard let chunkPath = chunkToUpload.path,
                      let sha256 = chunkToUpload.sha256 else {
                    throw DriveError.localError // TODO: Custom error
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
        file.uploadingSession = nil // TODO: Is this the correct thing to do ?
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
            UploadOperationLog("Task is cancelled \(file.id)", level: .error)
            throw DriveError.localError
        }
        
        return driveFileManager
    }
    
    /// Throws if the file was modified
    func checkFileIdentity(uploadingSession: UploadingSessionTask) throws {
        guard uploadingSession.fileIdentityHasNotChanged == true else {
            UploadOperationLog("File has changed \(uploadingSession.fileIdentity)≠\(uploadingSession.currentFileIdentity) fid:\(file.id)", level: .error)
            // Clean the existing upload session, so we can restart it later
            cleanUploadFileSession()
            throw DriveError.fileIdentityHasChanged
        }
    }
        
    func fileIdentity(fileUrl: URL) -> String {
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
    func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        enqueue(asap: true) {
            let file = self.file
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        
            if let error {
                UploadOperationLog("uploadCompletion data:\(data) response:\(response) error:\(error) fid:\(file.id)", level: .error)
            } else {
//                UploadOperationLog("uploadCompletion data:\(data) response:\(response) fid:\(file.id)")
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
        UploadOperationLog("completion successful response:\(response) \(file.id)")
     
        guard let uploadedChunk = try? ApiFetcher.decoder.decode(ApiResponse<UploadedChunk>.self, from: data).data else {
            UploadOperationLog("parsing error fid:\(file.id)")
            throw DriveError.parseError
        }
        UploadOperationLog("chunk:\(uploadedChunk.number)  fid:\(file.id)")
             
        // update current UploadFile with chunk
        guard let uploadingSessionTask = file.uploadingSession else {
            throw DriveError.uploadSessionTaskMissing
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
            throw DriveError.unableToMatchUploadChunk   // TODO: This should trigger a Sentry
        }
         
        // Update UI progress state
        let progress = uploadProgress()
        uploadProgressable.publishProgress(progress, for: file.id)
        
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
            enqueue {
                UploadOperationLog("Remaining \(toUploadCount) chunks to be uploaded \(self.file.id)")
                _ = try? self.generateChunksAndFanOutIfNeeded()
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
        
        file.error = error
        if error == .quotaExceeded {
            file.maxRetryCount = 0
        } else if error == .objectNotFound {
            // If we get an ”object not found“ error, we cancel all further uploads in this folder
            file.maxRetryCount = 0
            uploadQueue.cancelAllOperations(withParent: file.parentDirectoryId,
                                            userId: file.userId,
                                            driveId: file.driveId)
                
            if photoLibraryUploader.isSyncEnabled
                && photoLibraryUploader.settings?.parentDirectoryId == file.parentDirectoryId {
                photoLibraryUploader.disableSync()
                NotificationsHelper.sendPhotoSyncErrorNotification()
            }
        }
    }

    // System notification that we took over 30sec, and should cancel the task.
    private func backgroundTaskExpired() {
        enqueue(asap: true) {
            UploadOperationLog("backgroundTaskExpired enter\(self.file.id)")
            let breadcrumb = Breadcrumb(level: .info, category: "BackgroundUploadTask")
            breadcrumb.message = "Rescheduling file \(self.file.name)"
            breadcrumb.data = ["File id": self.file.id,
                               "File name": self.file.name,
                               "File size": self.file.size,
                               "File type": self.file.type.rawValue]
            SentrySDK.addBreadcrumb(crumb: breadcrumb)
            
            // TODO: this should be done somewhere outside the upload operation.
            /// Reschedule existing resquests to background session
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
            self.uploadQueue.suspendAllOperations()
            self.end()
        }
    }

    // did finish in time
    private func end() {
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
        
        // Save upload file
        result.uploadFile = UploadFile(value: file)
        if file.error != .taskCancelled {
            synchronousSaveUploadFileToRealm()
        }
        // Clean session and remove UploadFile
        else {
            cleanUploadFileSession()
            BackgroundRealm.uploads.execute { uploadsRealm in
                if let toDelete = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: file.id) {
                    try? uploadsRealm.safeWrite {
                        uploadsRealm.delete(toDelete)
                    }
                }
            }
        }

        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
    }
}
