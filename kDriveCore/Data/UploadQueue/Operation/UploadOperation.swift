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
import Photos
import RealmSwift
import Sentry
import UIKit

public struct UploadCompletionResult {
    var uploadFile: UploadFile?
    var driveFile: File?
}

public final class UploadOperation: AsynchronousOperation, UploadOperationable, ExpiringActivityDelegate {
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
        /// Cannot decrease further retry count, already zero
        case retryCountIsZero
    }

    // MARK: - Attributes

    @LazyInjectService var backgroundUploadManager: BackgroundUploadSessionManager
    @LazyInjectService var uploadQueue: UploadQueueable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var fileManager: FileManagerable
    @LazyInjectService var fileMetadata: FileMetadatable
    @LazyInjectService var freeSpaceService: FreeSpaceService
    @LazyInjectService var uploadNotifiable: UploadNotifiable
    @LazyInjectService var notificationHelper: NotificationsHelpable

    override public var debugDescription: String {
        """
        <\(type(of: self)):\(super.debugDescription)
        uploading file id:'\(uploadFileId)'
        parallelism :\(Self.parallelism)
        expiringActivity:'\(String(describing: expiringActivity))'>
        """
    }

    /// The number of requests we try to keep running in one UploadOperation
    private static let parallelism: Int = {
        // In extension to reduce memory footprint, we reduce parallelism in Extension
        let parallelism: Int
        if Bundle.main.isExtension {
            parallelism = 2 // With a chuck of 1MiB max, we allocate 2MiB max in this Operation
        } else {
            parallelism = max(4, ProcessInfo.processInfo.activeProcessorCount)
        }

        return parallelism
    }()

    public let uploadFileId: String
    private var fileObservationToken: NotificationToken?

    /// Local tracking of running network tasks
    /// The key used is the and absolute identifier of the task.
    var uploadTasks = [String: URLSessionUploadTask]()

    private let urlSession: URLSession
    private var expiringActivity: ExpiringActivityable?

    public var result: UploadCompletionResult

    // MARK: - Public methods -

    public required init(uploadFileId: String, urlSession: URLSession = URLSession.shared) {
        Log.uploadOperation("init ufid:\(uploadFileId)")
        self.uploadFileId = uploadFileId
        self.urlSession = urlSession
        result = UploadCompletionResult()

        super.init()
    }

    override public func execute() async {
        Log.uploadOperation("execute \(uploadFileId)")
        SentryDebug.uploadOperationBeginBreadcrumb(uploadFileId)

        await catching {
            try self.checkCancelation()
            try self.freeSpaceService.checkEnoughAvailableSpaceForChunkUpload()

            // Fetch a background task identifier
            self.beginExpiringActivity()

            // Fetch content from local library if needed
            try await self.getPhAssetIfNeeded()

            // Check if the file is empty, and uses the 1 shot upload method for it if needed.
            let handledEmptyFile = try await self.handleEmptyFileIfNeeded()

            // Continue if we are dealing with a file with data
            guard !handledEmptyFile else {
                return
            }

            // Re-Load or Setup an UploadingSessionTask within the UploadingFile
            try await self.getUploadSessionOrCreate()

            // Start chunking
            try await self.generateChunksAndFanOutIfNeeded()
        }
    }

    // MARK: - Split operations

    func beginExpiringActivity() {
        let activity = ExpiringActivity(id: uploadFileId, delegate: self)
        activity.start()
        expiringActivity = activity
    }

    func handleEmptyFileIfNeeded() async throws -> Bool {
        var fileSize: UInt64?
        var uploadFile: UploadFile?
        try transactionWithFile { file in
            let fileUrl = try self.getFileUrlIfReadable(file: file)
            guard let size = self.fileMetadata.fileSize(url: fileUrl) else {
                Log.uploadOperation("Unable to read file size for ufid:\(self.uploadFileId) url:\(fileUrl)", level: .error)
                throw DriveError.fileNotFound
            }

            fileSize = size
            uploadFile = file.detached()
        }

        guard let uploadFile,
              fileSize == 0 else {
            return false // Continue with standard upload operation
        }

        Log.uploadOperation("Processing an empty file ufid:\(uploadFileId)")
        let driveFileManager = try getDriveFileManager(for: uploadFile.driveId, userId: uploadFile.userId)
        let drive = driveFileManager.drive

        let driveFile = try await driveFileManager.apiFetcher.directUpload(drive: drive,
                                                                           totalSize: 0,
                                                                           fileName: uploadFile.name,
                                                                           conflictResolution: uploadFile.conflictOption,
                                                                           lastModifiedAt: uploadFile.modificationDate,
                                                                           createdAt: uploadFile.creationDate,
                                                                           directoryId: uploadFile.parentDirectoryId,
                                                                           directoryPath: uploadFile.relativePath,
                                                                           fileData: Data())

        try handleDriveFilePostUpload(driveFile)

        Log.uploadOperation("Empty file uploaded finishing fid:\(driveFile.id) ufid:\(uploadFileId)")
        end()
        return true
    }

    /// Fetch or create something that represents the state of the upload, and store it to the current UploadFile
    func getUploadSessionOrCreate() async throws {
        try checkCancelation()
        try freeSpaceService.checkEnoughAvailableSpaceForChunkUpload()

        // Set progress to zero if needed
        updateUploadProgress()

        Log.uploadOperation("Asking for an upload Session \(uploadFileId)")

        let uploadId = uploadFileId
        var uploadingSession: UploadingSessionTask?
        var error: ErrorDomain?
        try transactionWithFile { file in
            SentryDebug.uploadOperationRetryCountDecreaseBreadcrumb(uploadId, file.maxRetryCount)

            /// If cannot retry, throw
            guard file.maxRetryCount > 0 else {
                error = ErrorDomain.retryCountIsZero
                return
            }

            // Decrease retry count
            file.maxRetryCount -= 1

            uploadingSession = file.uploadingSession?.detached()
        }

        if let error {
            throw error
        }

        // fetch stored session
        if let uploadingSession {
            guard uploadingSession.fileIdentityHasNotChanged else {
                throw ErrorDomain.fileIdentityHasChanged
            }

            // Session is expired, regenerate it from scratch
            guard !uploadingSession.isExpired else {
                cleanUploadFileSession()
                try await generateNewSessionAndStore()
                return
            }

            try await fetchAndCleanStoredSession()
        }

        // generate a new session
        else {
            try await generateNewSessionAndStore()
        }

        // Update progress once the session was created
        updateUploadProgress()
    }

    /// Generate some chunks into a temporary folder from a file
    func generateChunksAndFanOutIfNeeded() async throws {
        Log.uploadOperation("generateChunksAndFanOutIfNeeded ufid:\(uploadFileId)")
        try checkCancelation()

        var filePath = ""
        var chunksToGenerateCount = 0
        try transactionWithFile { file in
            // Get the current uploading session
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            filePath = uploadingSessionTask.filePath
            let sessionToken = uploadingSessionTask.token
            try self.checkFileIdentity(filePath: filePath, file: file)

            // Look for the next chunk to generate
            let chunksToGenerate = uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.notDoneUploadingPredicate)
                .filter { $0.hasLocalChunk == false }
            guard let chunkTask = chunksToGenerate.first else {
                Log.uploadOperation("generateChunksAndFanOutIfNeeded no remaining chunks to generate ufid:\(self.uploadFileId)")
                return
            }
            Log.uploadOperation("generateChunksAndFanOutIfNeeded working with:\(chunkTask.chunkNumber) ufid:\(self.uploadFileId)")

            chunksToGenerateCount = chunksToGenerate.count
            let chunkNumber = chunkTask.chunkNumber
            let range = chunkTask.range
            let fileUrl = try self.getFileUrlIfReadable(file: file)
            guard let chunkProvider = ChunkProvider(fileURL: fileUrl, ranges: [range]),
                  let chunk = chunkProvider.next() else {
                Log.uploadOperation("Unable to get a ChunkProvider for \(self.uploadFileId)", level: .error)
                throw ErrorDomain.chunkError
            }

            Log.uploadOperation(
                "Storing Chunk count:\(chunkNumber) of \(chunksToGenerateCount) to write, ufid:\(self.uploadFileId)"
            )
            do {
                try self.checkFileIdentity(filePath: filePath, file: file)
                try self.checkCancelation()

                let chunkSHA256 = chunk.SHA256DigestString
                let chunkPath = try self.storeChunk(chunk,
                                                    number: chunkNumber,
                                                    uploadFileId: self.uploadFileId,
                                                    sessionToken: sessionToken,
                                                    hash: chunkSHA256)
                Log.uploadOperation("chunk stored count:\(chunkNumber) for:\(self.uploadFileId)")

                // set path + sha
                chunkTask.path = chunkPath.path
                chunkTask.sha256 = chunkSHA256

            } catch {
                Log.uploadOperation(
                    "Unable to save a chunk to storage. number:\(chunkNumber) error:\(error) for:\(self.uploadFileId)",
                    level: .error
                )
                throw error
            }
        }

        // Schedule next step
        try await scheduleNextChunk(filePath: filePath,
                                    chunksToGenerateCount: chunksToGenerateCount)
    }

    /// Prepare chunk upload requests, and start them.
    private func scheduleNextChunk(filePath: String, chunksToGenerateCount: Int) async throws {
        do {
            try checkFileIdentity(filePath: filePath)
            try checkCancelation()

            // Fan-out the chunk we just made
            enqueueCatching {
                try await self.fanOutChunks()
            }

            // Chain the next chunk generation if necessary
            let slots = freeRequestSlots()
            if chunksToGenerateCount > 0 && slots > 0 {
                Log.uploadOperation(
                    "remaining chunks to generate:\(chunksToGenerateCount) slots:\(slots) scheduleNextChunk OP ufid:\(uploadFileId)"
                )
                enqueueCatching {
                    try await self.generateChunksAndFanOutIfNeeded()
                }
            }
        } catch {
            Log.uploadOperation("Unable to schedule next chunk. error:\(error) for:\(uploadFileId)", level: .error)
            throw error
        }
    }

    /// Prepare chunk upload requests, and start them.
    func fanOutChunks() async throws {
        try checkCancelation()

        let freeSlots = freeRequestSlots()
        guard freeSlots > 0 else {
            return
        }

        try transactionWithFile { file in
            // Get the current uploading session
            guard let uploadingSessionTask: UploadingSessionTask = file.uploadingSession else {
                Log.uploadOperation("fanOut no session for:\(self.uploadFileId)", level: .error)
                throw ErrorDomain.uploadSessionTaskMissing
            }

            let chunksToUpload = Array(uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.canStartUploadingPreconditionPredicate)
                .filter { $0.hasLocalChunk == true })
                .prefix(freeSlots) // Iterate over only the available worker slots

            Log.uploadOperation("fanOut chunksToUpload:\(chunksToUpload.count) freeSlots:\(freeSlots) for:\(self.uploadFileId)")

            // Access Token must be added for non AF requests
            let accessToken = self.accountManager.getTokenForUserId(file.userId)?.accessToken
            guard let accessToken else {
                Log.uploadOperation("no access token found", level: .error)
                throw ErrorDomain.unableToBuildRequest
            }

            // Schedule all the chunks to be uploaded
            for chunkToUpload: UploadingChunkTask in chunksToUpload {
                try self.checkCancelation()

                do {
                    guard let chunkPath = chunkToUpload.path,
                          let sha256 = chunkToUpload.sha256 else {
                        throw ErrorDomain.missingChunkHash
                    }

                    let chunkHashHeader = "sha256:\(sha256)"
                    let chunkUrl = URL(fileURLWithPath: chunkPath, isDirectory: false)
                    let chunkNumber = chunkToUpload.chunkNumber
                    let chunkSize = chunkToUpload.chunkSize
                    let request = try self.buildRequest(chunkNumber: chunkNumber,
                                                        chunkSize: chunkSize,
                                                        chunkHash: chunkHashHeader,
                                                        sessionToken: uploadingSessionTask.token,
                                                        driveId: file.driveId,
                                                        accessToken: accessToken)
                    let uploadTask = self.urlSession.uploadTask(with: request,
                                                                fromFile: chunkUrl,
                                                                completionHandler: self.uploadCompletion)
                    // Extra 512 bytes for request headers
                    uploadTask.countOfBytesClientExpectsToSend = Int64(chunkSize) + 512
                    // 5KB is a very reasonable upper bound size for a file server response (max observed: 1.47KB)
                    uploadTask.countOfBytesClientExpectsToReceive = 1024 * 5

                    chunkToUpload.sessionIdentifier = self.urlSession.identifier
                    chunkToUpload.taskIdentifier = self.urlSession.identifier(for: uploadTask)
                    chunkToUpload.requestUrl = request.url?.absoluteString

                    let identifier = self.urlSession.identifier(for: uploadTask)
                    self.uploadTasks[identifier] = uploadTask
                    uploadTask.resume()

                    Log.uploadOperation("started task identifier:\(identifier) for:\(self.uploadFileId)")

                } catch {
                    Log.uploadOperation(
                        "Unable to create an upload request for chunk \(chunkToUpload) error:\(error) - \(self.uploadFileId)",
                        level: .error
                    )
                    throw error
                }
            }
        }
    }

    func getFileUrlIfReadable(file: UploadFile) throws -> URL {
        guard let fileUrl = file.pathURL,
              fileManager.isReadableFile(atPath: fileUrl.path) else {
            Log.uploadOperation("File has not a valid readable URL:\(file.pathURL?.path) for \(uploadFileId)",
                                level: .error)
            throw DriveError.fileNotFound
        }
        return fileUrl
    }

    public func cleanUploadFileSession(file: UploadFile? = nil) {
        Log.uploadOperation("Clean uploading session for \(uploadFileId)")
        SentryDebug.uploadOperationCleanSessionBreadcrumb(uploadFileId)

        let cleanFileClosure: (UploadFile) -> Void = { file in
            // Clean the remote session, if valid. Invalid ones are already gone server side.
            let driveId = file.driveId
            let userId = file.userId
            let uploadingSession = file.uploadingSession?.detached()
            self.enqueue {
                guard let session = uploadingSession,
                      !session.isExpired else {
                    return
                }

                guard let driveFileManager = try? self.getDriveFileManager(for: driveId, userId: userId) else {
                    return
                }

                let abstractToken = AbstractTokenWrapper(token: session.token)
                let apiFetcher = driveFileManager.apiFetcher
                let drive = driveFileManager.drive

                // We try to cancel the upload session, we discard results
                let cancelResult = try? await apiFetcher.cancelSession(drive: drive, sessionToken: abstractToken)
                Log.uploadOperation("cancelSession remotely:\(String(describing: cancelResult)) for \(self.uploadFileId)")
                SentryDebug.uploadOperationCleanSessionRemotelyBreadcrumb(self.uploadFileId, cancelResult ?? false)
            }

            file.uploadingSession = nil
            file.progress = nil

            // reset errors
            file.error = nil

            // Cancel all network requests
            self.cancelAllUploadRequests()
        }

        // If no file provided, wrap the transaction
        if let file {
            cleanFileClosure(file)
        } else {
            try? transactionWithFile { file in
                cleanFileClosure(file)
            }
        }
    }

    /// Cancel all tracked URLSessionUploadTasks
    private func cancelAllUploadRequests() {
        // Free local resources
        for (key, value) in uploadTasks {
            Log.uploadOperation("cancelled chunk upload request :\(key) ufid:\(uploadFileId)")
            value.cancel()
        }
        uploadTasks.removeAll()
    }

    /// Throws if the file was modified
    func checkFileIdentity(filePath: String, file: UploadFile? = nil) throws {
        guard fileManager.isReadableFile(atPath: filePath) else {
            Log.uploadOperation("File has not a valid readable URL:'\(filePath)' for \(uploadFileId)",
                                level: .error)
            throw DriveError.fileNotFound
        }

        let task: (_ file: UploadFile) throws -> Void = { file in
            guard let uploadingSession = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            guard uploadingSession.fileIdentityHasNotChanged else {
                Log.uploadOperation(
                    "File has changed \(uploadingSession.fileIdentity)≠\(uploadingSession.currentFileIdentity) ufid:\(self.uploadFileId)",
                    level: .error
                )
                throw ErrorDomain.fileIdentityHasChanged
            }
        }

        if let file {
            try task(file)
        } else {
            try transactionWithFile { file in
                try task(file)
            }
        }
    }

    /// Throws if UploadOperation is canceled
    func checkCancelation() throws {
        if isCancelled {
            Log.uploadOperation("Task is cancelled \(uploadFileId)")
            throw ErrorDomain.operationCanceled
        } else if isFinished {
            Log.uploadOperation("Task is isFinished \(uploadFileId)")
            throw ErrorDomain.operationFinished
        }
    }

    /// Close session if needed.
    func closeSessionAndEnd() async {
        Log.uploadOperation("closeSession ufid:\(uploadFileId)")
        SentryDebug.uploadOperationCloseSessionAndEndBreadcrumb(uploadFileId)

        defer {
            end()
        }

        var uploadSessionToken: String?
        var userId: Int?
        var driveId: Int?
        try? transactionWithFile { file in
            uploadSessionToken = file.uploadingSession?.token
            userId = file.userId
            driveId = file.driveId
        }

        guard let uploadSessionToken, let userId, let driveId else {
            Log.uploadOperation("No existing session to close ufid:\(uploadFileId)")
            return
        }

        var driveFileManager: DriveFileManager?
        await catching {
            driveFileManager = try self.getDriveFileManager(for: driveId, userId: userId)
        }

        guard let driveFileManager else {
            Log.uploadOperation("No drivefilemanager to close ufid:\(uploadFileId)")
            return
        }

        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive
        let abstractToken = AbstractTokenWrapper(token: uploadSessionToken)

        await catching {
            let uploadedFile = try await apiFetcher.closeSession(drive: drive, sessionToken: abstractToken)
            let driveFile = uploadedFile.file
            Log.uploadOperation("uploadedFile 'File' id:\(uploadedFile.file.id) ufid:\(self.uploadFileId)")
            try self.handleDriveFilePostUpload(driveFile)
        }
    }

    /// The last step in the operation, should be called. In time or not. Regardless of error state.
    public func end() {
        // Prevent duplicate call, as end() finishes the operation
        guard !isFinished else {
            return
        }

        defer {
            // Terminate the NSOperation
            Log.uploadOperation("call finish ufid:\(uploadFileId)")

            // Make sure we stop the expiring activity
            self.expiringActivity?.end()

            finish()

            SentryDebug.uploadOperationFinishedBreadcrumb(uploadFileId)
        }

        try? debugWithFile { file in
            SentryDebug.uploadOperationEndBreadcrumb(self.uploadFileId, file.error)
        }

        var shouldCleanUploadFile = false
        try? transactionWithFile { file in

            if let error = file.error {
                Log.uploadOperation("end file ufid:\(self.uploadFileId) errorCode: \(error.code) error:\(error)", level: .error)
            } else {
                Log.uploadOperation("end file ufid:\(self.uploadFileId)")
            }

            if let path = file.pathURL,
               file.shouldRemoveAfterUpload && file.uploadDate != nil {
                Log.uploadOperation("Remove local file at path:\(path) ufid:\(self.uploadFileId)")
                try? self.fileManager.removeItem(at: path)
            }

            // retry from scratch next time
            if file.maxRetryCount <= 0 {
                self.cleanUploadFileSession(file: file)
            }

            // If task is cancelled, remove it from list
            if file.error == DriveError.taskCancelled {
                shouldCleanUploadFile = true
            }

            // otherwise only reset success
            else {
                file.progress = nil

                // Save upload file
                self.result.uploadFile = UploadFile(value: file)
            }
        }

        if shouldCleanUploadFile {
            Log.uploadOperation("Delete file ufid:\(uploadFileId)")
            // Delete UploadFile as canceled by the user
            BackgroundRealm.uploads.execute { uploadsRealm in
                if let toDelete = uploadsRealm.object(ofType: UploadFile.self, forPrimaryKey: self.uploadFileId),
                   !toDelete.isInvalidated {
                    try? uploadsRealm.safeWrite {
                        uploadsRealm.delete(toDelete)
                    }
                }
            }
        }
    }

    // MARK: - Private methods -

    // MARK: Progress

    /// Returns  the upload progress. Ranges from 0 to 1.
    @discardableResult private func updateUploadProgress() -> Double {
        // Get the current uploading session
        guard let chunkTasksUploadedCount = try? chunkTasksUploadedCount(),
              let chunkTasksTotalCount = try? chunkTasksTotalCount() else {
            let noProgress: Double = 0
            try? transactionWithFile { file in
                file.progress = noProgress
            }
            return noProgress
        }

        // We have a valid session and chunks to upload, so progress in non 0 for consistent UI.
        let progress = max(Double(chunkTasksUploadedCount) / Double(chunkTasksTotalCount), 0.01)
        try? transactionWithFile { file in
            file.progress = progress
        }

        return progress
    }

    // MARK: UploadSession

    /// fetch stored session
    private func fetchAndCleanStoredSession() async throws {
        Log.uploadOperation("fetchAndCleanStoredSession ufid:\(uploadFileId)")
        try transactionWithFile { file in
            guard let uploadingSession = file.uploadingSession,
                  !uploadingSession.isExpired else {
                throw ErrorDomain.uploadSessionInvalid
            }

            guard uploadingSession.fileIdentityHasNotChanged else {
                throw ErrorDomain.fileIdentityHasChanged
            }

            // Cleanup the uploading chunks and session state for re-use
            let chunkTasksToClean = uploadingSession.chunkTasks.filter(UploadingChunkTask.notDoneUploadingPredicate)
            chunkTasksToClean.forEach {
                // clean in order to re-schedule
                $0.sessionIdentifier = nil
                $0.taskIdentifier = nil
                $0.requestUrl = nil
                $0.path = nil
                $0.sha256 = nil
                $0.error = nil
            }
        }

        // if we have no more chunks to upload, try to close session
        await catching {
            guard let chunkTasksToUploadCount = try? self.chunkTasksToUploadCount() else {
                return
            }

            // All chunks are uploaded, try to close the session
            if chunkTasksToUploadCount == 0 {
                Log.uploadOperation("No remaining chunks to upload at restart, closing session ufid:\(self.uploadFileId)")
                await self.closeSessionAndEnd()
            }
        }

        // We have a valid upload session
    }

    /// generate a new session
    private func generateNewSessionAndStore() async throws {
        Log.uploadOperation("generateNewSession ufid:\(uploadFileId)")
        var fileName: String?
        var conflictOption: ConflictOption?
        var parentDirectoryId: Int?
        var fileUrl: URL?
        var modificationDate: Date?
        var creationDate: Date?
        var relativePath: String?
        var userId: Int?
        var driveId: Int?
        try transactionWithFile { file in
            fileName = file.name
            conflictOption = file.conflictOption
            parentDirectoryId = file.parentDirectoryId

            // Check file is readable
            fileUrl = try self.getFileUrlIfReadable(file: file)

            // Dates and path override, for PHAssets.
            modificationDate = file.modificationDate
            creationDate = file.creationDate
            relativePath = file.relativePath

            userId = file.userId
            driveId = file.driveId
        }

        guard let fileName, let conflictOption, let parentDirectoryId, let fileUrl, let userId, let driveId else {
            throw ErrorDomain.unableToBuildRequest
        }

        guard let fileSize = fileMetadata.fileSize(url: fileUrl) else {
            Log.uploadOperation("Unable to read file size for ufid:\(uploadFileId) url:\(fileUrl)", level: .error)
            throw DriveError.fileNotFound
        }

        let mebibytes = String(format: "%.2f", BinaryDisplaySize.bytes(fileSize).toMebibytes)
        Log.uploadOperation("got fileSize:\(mebibytes)MiB ufid:\(uploadFileId)")

        // Compute ranges for a file
        let rangeProvider = RangeProvider(fileURL: fileUrl)
        let ranges: [DataRange]
        do {
            ranges = try rangeProvider.allRanges
        } catch {
            Log.uploadOperation("Unable generate ranges error:\(error) for ufid\(uploadFileId)", level: .error)
            throw ErrorDomain.splitError
        }
        Log.uploadOperation("got ranges:\(ranges.count) ufid:\(uploadFileId)")

        // Get a valid APIV2 UploadSession
        let driveFileManager = try getDriveFileManager(for: driveId, userId: userId)
        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive

        let session = try await apiFetcher.startSession(drive: drive,
                                                        totalSize: fileSize,
                                                        fileName: fileName,
                                                        totalChunks: ranges.count,
                                                        conflictResolution: conflictOption,
                                                        lastModifiedAt: modificationDate,
                                                        createdAt: creationDate,
                                                        directoryId: parentDirectoryId,
                                                        directoryPath: relativePath)
        Log.uploadOperation("New session token:\(session.token) ufid:\(uploadFileId)")
        try transactionWithFile { file in
            // Create an uploading session
            let uploadingSessionTask = UploadingSessionTask()

            // Store the session token asap as a non null ivar
            uploadingSessionTask.token = session.token

            // The file at the moment we created the UploadingSessionTask
            uploadingSessionTask.filePath = fileUrl.path

            // Store the session
            uploadingSessionTask.uploadSession = session

            // Make sure we can track the the file has not changed across time, while we run the upload session
            let fileIdentity = UploadingSessionTask.fileIdentity(fileUrl: fileUrl)
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

    // MARK: Build request

    private func buildRequest(chunkNumber: Int64,
                              chunkSize: Int64,
                              chunkHash: String,
                              sessionToken: String,
                              driveId: Int,
                              accessToken: String) throws -> URLRequest {
        // Access Token must be added for non AF requests
        let headerParameters = ["Authorization": "Bearer \(accessToken)"]
        let headers = HTTPHeaders(headerParameters)
        let route: Endpoint = .appendChunk(drive: AbstractDriveWrapper(id: driveId),
                                           sessionToken: AbstractTokenWrapper(token: sessionToken))

        guard var urlComponents = URLComponents(url: route.url, resolvingAgainstBaseURL: false) else {
            throw ErrorDomain.unableToBuildRequest
        }

        let getParameters = [
            URLQueryItem(name: APIUploadParameter.chunkNumber.rawValue, value: "\(chunkNumber)"),
            URLQueryItem(name: APIUploadParameter.chunkSize.rawValue, value: "\(chunkSize)"),
            URLQueryItem(name: APIUploadParameter.chunkHash.rawValue, value: chunkHash)
        ]
        urlComponents.queryItems = getParameters

        guard let url = urlComponents.url else {
            throw ErrorDomain.unableToBuildRequest
        }

        return try URLRequest(url: url, method: .post, headers: headers)
    }

    // MARK: Chunks

    private func storeChunk(_ buffer: Data, number: Int64, uploadFileId: String, sessionToken: String,
                            hash: String) throws -> URL {
        // Create subfolders if needed
        let tempChunkFolder = buildFolderPath(fileId: uploadFileId, sessionToken: sessionToken)
        Log.uploadOperation("using chunk folder:'\(tempChunkFolder)' ufid:\(uploadFileId)")
        if !fileManager.fileExists(atPath: tempChunkFolder.path, isDirectory: nil) {
            try fileManager.createDirectory(at: tempChunkFolder, withIntermediateDirectories: true, attributes: nil)
        }

        // Write buffer
        let chunkName = chunkName(number: number, fileId: uploadFileId, hash: hash)
        let chunkPath = tempChunkFolder.appendingPathExtension(chunkName)
        try buffer.write(to: chunkPath, options: [.atomic])
        Log.uploadOperation("wrote chunk:\(chunkPath) ufid:\(uploadFileId)")

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

    private func getPhAssetIfNeeded() async throws {
        Log.uploadOperation("getPhAssetIfNeeded ufid:\(uploadFileId)")
        var assetToLoad: PHAsset?
        try transactionWithFile { file in
            Log.uploadOperation("getPhAssetIfNeeded type:\(file.type) ufid:\(self.uploadFileId)")
            guard file.type == .phAsset else {
                return
            }

            guard let asset = file.getPHAsset() else {
                Log.uploadOperation(
                    "Unable to fetch PHAsset ufid:\(self.uploadFileId) assetLocalIdentifier:\(file.assetLocalIdentifier) ",
                    level: .error
                )
                return
            }
            assetToLoad = asset
        }
        
        // This UploadFile is not a PHAsset, return silently
        guard let assetToLoad else {
            return
        }
        
        // Async load the url of the asset
        guard let url = await photoLibraryUploader.getUrl(for: assetToLoad) else {
            Log.uploadOperation("Failed to get photo asset URL ufid:\(uploadFileId)", level: .error)
            return
        }

        // Save asset file URL to DB
        Log.uploadOperation("Got photo asset, writing URL:\(url) ufid:\(uploadFileId)")
        try transactionWithFile { file in
            file.pathURL = url
            file.uploadingSession?.filePath = url.path
        }
    }

    // MARK: Background callback

    // also called on app restoration
    public func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        enqueue {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            // Success
            if let data,
               error == nil,
               statusCode >= 200, statusCode < 300 {
                await self.catching {
                    try await self.uploadCompletionSuccess(data: data, response: response, error: error)
                }
            }

            // Client-side error
            else if let error {
                await self.catching {
                    try self.uploadCompletionLocalFailure(data: data, response: response, error: error)
                }
            }

            // Server-side error
            else {
                self.uploadCompletionRemoteFailure(data: data, response: response, error: error)
            }
        }
    }

    private func uploadCompletionSuccess(data: Data, response: URLResponse?, error: Error?) async throws {
        Log.uploadOperation("completion successful \(uploadFileId)")

        guard let uploadedChunk = try? ApiFetcher.decoder.decode(ApiResponse<UploadedChunk>.self, from: data).data else {
            Log.uploadOperation("parsing error:\(error) ufid:\(uploadFileId)", level: .error)
            throw ErrorDomain.parseError
        }
        Log.uploadOperation("chunk:\(uploadedChunk.number)  ufid:\(uploadFileId)")

        try transactionWithFile { file in
            // update current UploadFile with chunk
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            // Store the chunk object into the correct chunkTask
            if let chunkTask = uploadingSessionTask.chunkTasks.first(where: { $0.chunkNumber == uploadedChunk.number }) {
                chunkTask.chunk = uploadedChunk

                // tracking running tasks
                if let identifier = chunkTask.taskIdentifier {
                    self.uploadTasks.removeValue(forKey: identifier)
                    chunkTask.taskIdentifier = nil
                } else {
                    Log.uploadOperation(
                        "No identifier for chunkId:\(uploadedChunk.number) in SUCCESS ufid:\(self.uploadFileId)",
                        level: .error
                    )
                    SentrySDK.capture(message: "Missing chunk identifier") { scope in
                        scope.setContext(
                            value: ["Chunk number": uploadedChunk.number, "fid": self.uploadFileId],
                            key: "Chunk Infos"
                        )
                    }

                    // We may be running both the app and the extension
                    assertionFailure("unable to lookup chunk task id, ufid:\(self.uploadFileId)")
                }

                // Some cleanup if we have the chance
                if let path = chunkTask.path {
                    let url = URL(fileURLWithPath: path, isDirectory: false)
                    let chunkNumber = chunkTask.chunkNumber
                    DispatchQueue.global(qos: .background).async {
                        Log.uploadOperation("cleanup chunk:\(chunkNumber) ufid:\(self.uploadFileId)")
                        try? self.fileManager.removeItem(at: url)
                    }
                }
            } else {
                Log.uploadOperation("matching chunk:\(uploadedChunk.number) failed ufid:\(self.uploadFileId)", level: .error)
                SentrySDK.capture(message: "Upload matching chunk failed") { scope in
                    scope.setContext(value: ["Chunk number": uploadedChunk.number, "fid": self.uploadFileId], key: "Chunk Infos")
                }

                self.cleanUploadFileSession(file: file)
                throw ErrorDomain.unableToMatchUploadChunk
            }
        }

        // Update UI progress state
        updateUploadProgress()

        // Close session and terminate task as the last chunk was uploaded
        let toUploadCount = try chunkTasksToUploadCount()
        if toUploadCount == 0 {
            enqueue {
                Log.uploadOperation("No more chunks to be uploaded \(self.uploadFileId)")
                if !self.isCancelled {
                    await self.closeSessionAndEnd()
                }
            }
        }

        // Follow up with chunking again
        else {
            enqueueCatching {
                let slots = self.freeRequestSlots()
                if slots > 0 {
                    try await self.generateChunksAndFanOutIfNeeded()
                }
            }
        }
    }

    /// Return the available request slots.
    private func freeRequestSlots() -> Int {
        let uploadTasksCount = uploadTasks.count
        let free = max(Self.parallelism - uploadTasksCount, 0)
        return free
    }

    private func uploadCompletionLocalFailure(data: Data?, response: URLResponse?, error: Error) throws {
        Log.uploadOperation("completion Client-side error:\(error) ufid:\(uploadFileId)", level: .error)
        defer {
            self.end()
        }

        handleLocalErrors(error: error)
    }

    private func uploadCompletionRemoteFailure(data: Data?, response: URLResponse?, error: Error?) {
        defer {
            self.end()
        }

        if let data {
            Log.uploadOperation(
                "uploadCompletionRemoteFailure dataString:\(String(decoding: data, as: UTF8.self)) ufid:\(uploadFileId)"
            )
        }

        var error = DriveError.serverError
        if let data,
           let apiError = try? ApiFetcher.decoder.decode(ApiResponse<Empty>.self, from: data).error {
            error = DriveError(apiError: apiError)
        }

        Log.uploadOperation("completion  Server-side error:\(error) ufid:\(uploadFileId) ", level: .error)
        handleRemoteErrors(error: error)
    }

    /// Propagate the newly uploaded DriveFile into the specialized Realm
    private func handleDriveFilePostUpload(_ driveFile: File) throws {
        var driveId: Int?
        var userId: Int?
        var relativePath: String?
        var parentDirectoryId: Int?
        try transactionWithFile { file in
            file.uploadDate = Date()
            file.uploadingSession = nil // For the sake of keeping the Realm small
            file.error = nil
            driveId = file.driveId
            userId = file.userId
            relativePath = file.relativePath
            parentDirectoryId = file.parentDirectoryId
        }

        guard let driveId,
              let userId,
              let relativePath,
              let parentDirectoryId,
              let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId) else {
            return
        }

        // File is already here or has parent in DB let's update it
        let queue = BackgroundRealm.getQueue(for: driveFileManager.realmConfiguration)
        queue.execute { realm in
            if driveFileManager.getCachedFile(id: driveFile.id, freeze: false, using: realm) != nil
                || relativePath.isEmpty {
                let parent = driveFileManager.getCachedFile(id: parentDirectoryId, freeze: false, using: realm)
                queue.bufferedWrite(in: parent, file: driveFile)
                self.result.driveFile = File(value: driveFile)
            }
        }
    }

    // MARK: - ExpiringActivityDelegate -

    public func backgroundActivityExpiring() {
        Log.uploadOperation("backgroundActivityExpiring ufid:\(uploadFileId)")
        SentryDebug.uploadOperationBackgroundExpiringBreadcrumb(uploadFileId)

        enqueueCatching {
            try self.transactionWithFile { file in
                file.error = .taskRescheduled
                Log.uploadOperation("Rescheduling didReschedule .taskRescheduled ufid:\(self.uploadFileId)")

                let metadata = ["File id": self.uploadFileId,
                                "File name": file.name,
                                "File size": file.size,
                                "File type": file.type.rawValue]
                SentryDebug.uploadOperationRescheduledBreadcrumb(self.uploadFileId, metadata)
            }

            self.uploadNotifiable.sendPausedNotificationIfNeeded()

            // Cancel all network requests
            self.cancelAllUploadRequests()

            // each and all operations should be given the chance to call backgroundActivityExpiring
            self.end()

            Log.uploadOperation("Rescheduling end ufid:\(self.uploadFileId)")
        }
        Log.uploadOperation("exit reschedule ufid:\(uploadFileId)")
    }
}
