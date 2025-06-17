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
import InfomaniakCoreDB
import InfomaniakDI
import Photos
import RealmSwift
import UIKit

public struct UploadCompletionResult {
    var uploadFile: UploadFile?
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
        /// Cannot upload image because we are not in wifi
        case uploadOverDataRestrictedError
    }

    // MARK: - Attributes

    @LazyInjectService var backgroundUploadManager: BackgroundUploadSessionManager
    @LazyInjectService var uploadService: UploadServiceable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploadable
    @LazyInjectService var photoLibrarySync: PhotoLibrarySyncable
    @LazyInjectService var fileManager: FileManagerable
    @LazyInjectService var fileMetadata: FileMetadatable
    @LazyInjectService var freeSpaceService: FreeSpaceService
    @LazyInjectService var uploadNotifiable: UploadNotifiable
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService(customTypeIdentifier: kDriveDBID.uploads) var uploadsDatabase: Transactionable

    /// The number of chunks we try to keep ready to upload in one UploadOperation
    private static let parallelism = 2

    /// An Activity to prevent the system from interrupting it without been notified beforehand
    private var expiringActivity: ExpiringActivityable?

    /// Local tracking of running network tasks
    /// The key used is the and absolute identifier of the task.
    let uploadTasks = SendableDictionary<String, URLSessionUploadTask>()

    /// The url session used to upload chunks
    let urlSession: URLSession

    override public var debugDescription: String {
        """
        <\(type(of: self)):\(super.debugDescription)
        uploading file id:'\(uploadFileId)'
        parallelism :\(Self.parallelism)
        expiringActivity:'\(String(describing: expiringActivity))'>
        """
    }

    /// The id of the entity in base representing the upload task
    public let uploadFileId: String

    /// Object used to pass a completion state beyond to the OperationQueue
    public var result: UploadCompletionResult

    // MARK: - Public methods -

    public required init(uploadFileId: String, urlSession: URLSession = URLSession.shared) {
        Log.uploadOperation("init ufid:\(uploadFileId)")
        self.uploadFileId = uploadFileId
        self.urlSession = urlSession
        result = UploadCompletionResult()

        super.init()
    }

    /// The main steps of the operation are expressed here.
    override public func execute() async {
        Log.uploadOperation("execute \(uploadFileId)")
        SentryDebug.uploadOperationBeginBreadcrumb(uploadFileId)

        await catching {
            try self.checkCancelation()
            try self.freeSpaceService.checkEnoughAvailableSpaceForChunkUpload()

            // Fetch a background task identifier
            self.beginExpiringActivity()

            // Clean existing error if any
            try self.cleanUploadFileError()

            // Pause the upload depending on the status
            try self.checkForRestrictedUploadOverDataMode()

            // Fetch content from local library if needed
            try await self.getPhAssetIfNeeded()

            // Check if the file is empty, and uses the 1 shot upload method for it if needed.
            let handledEmptyFile = try await self.handleSmallOrEmptyFileIfNeeded()

            // Continue if we are dealing with a file with data
            guard !handledEmptyFile else {
                return
            }

            // Re-Load or Setup an UploadingSessionTask within the UploadingFile
            try await self.refreshUploadSessionOrCreate()

            // Start chunking
            try await self.generateChunksAndFanOutIfNeeded()
        }
    }

    // MARK: - Process steps

    /// Start to track the app going to background to be notified when the system would like to terminate
    func beginExpiringActivity() {
        let activity = ExpiringActivity(id: uploadFileId, delegate: self)
        activity.start()
        expiringActivity = activity
    }

    /// Return the available chunking slots.
    func availableWorkerSlots() -> Int {
        let uploadTasksCount = uploadTasks.count
        let free = max(Self.parallelism - uploadTasksCount, 0)
        return free
    }

    func handleSmallOrEmptyFileIfNeeded() async throws -> Bool {
        try checkCancelation()

        let uploadFile = try readOnlyFile()
        let fileUrl = try getFileUrlIfReadable(file: uploadFile)
        guard let fileSize = fileMetadata.fileSize(url: fileUrl) else {
            Log.uploadOperation("Unable to read file size for ufid:\(uploadFileId) url:\(fileUrl)", level: .error)
            throw DriveError.fileNotFound
        }

        guard fileSize < RangeProvider.APIConstants.smallFileMaxSize else {
            return false // Continue with standard upload operation
        }

        let fileData: Data
        if fileSize == 0 {
            Log.uploadOperation("Processing empty file ufid:\(uploadFileId)")
            fileData = Data()
        } else {
            Log.uploadOperation("Processing small file ufid:\(uploadFileId)")
            fileData = try Data(contentsOf: fileUrl)
        }

        let driveFileManager = try getDriveFileManager(for: uploadFile.driveId, userId: uploadFile.userId)
        let drive = driveFileManager.drive

        let driveFile = try await driveFileManager.apiFetcher.directUpload(drive: drive,
                                                                           totalSize: fileSize,
                                                                           fileName: uploadFile.name,
                                                                           conflictResolution: uploadFile.conflictOption,
                                                                           lastModifiedAt: uploadFile.modificationDate,
                                                                           createdAt: uploadFile.creationDate,
                                                                           directoryId: uploadFile.parentDirectoryId,
                                                                           directoryPath: uploadFile.relativePath,
                                                                           fileData: fileData)

        // Make sure the parent of the `File` is transferred from the `UploadFile`
        driveFile.parentId = uploadFile.parentDirectoryId

        try handleDriveFilePostUpload(driveFile)

        Log.uploadOperation("Small or empty file upload finishing fid:\(driveFile.id) ufid:\(uploadFileId)")
        end()
        return true
    }

    /// Make sure we start form a clean slate
    func cleanUploadFileError() throws {
        try transactionWithFile { file in
            file.error = nil
        }
    }

    func getFileUrlIfReadable(file: UploadFile) throws -> URL {
        guard let fileUrl = file.pathURL,
              fileManager.isReadableFile(atPath: fileUrl.path) else {
            Log.uploadOperation("File has not a valid readable URL:\(String(describing: file.pathURL?.path)) for \(uploadFileId)",
                                level: .error)
            throw DriveError.fileNotFound
        }
        return fileUrl
    }

    /// Cancel all tracked URLSessionUploadTasks
    func cancelAllUploadRequests() {
        var iterator = uploadTasks.makeIterator()
        while let (key, value) = iterator.next() {
            Log.uploadOperation("cancelled chunk upload request :\(key) ufid:\(uploadFileId)")
            value.cancel()
        }
        uploadTasks.removeAll()
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
            expiringActivity?.endAll()

            // Make sure we stop all the network requests (if any)
            cancelAllUploadRequests()

            finish()

            SentryDebug.uploadOperationFinishedBreadcrumb(uploadFileId)
        }

        let readOnlyFile = try? readOnlyFile()
        SentryDebug.uploadOperationEndBreadcrumb(uploadFileId, readOnlyFile?.error)

        var shouldCleanUploadFile = false
        try? transactionWithFile { file in
            if let error = file.error {
                Log.uploadOperation("end file ufid:\(self.uploadFileId) errorCode: \(error.code) error:\(error)", level: .error)
            } else {
                Log.uploadOperation("end file ufid:\(self.uploadFileId)")
            }

            // Remove source file if uploaded with success and required.
            if file.uploadDate != nil {
                if file.cleanSourceFileIfNeeded() {
                    Log.uploadOperation(
                        "Removed local file at path:\(String(describing: file.pathURL)) ufid:\(self.uploadFileId)"
                    )
                }
            } else {
                Log.uploadOperation(
                    "Not removing local file, shouldRemove:\(file.shouldRemoveAfterUpload)  at path:\(String(describing: file.pathURL)) ufid:\(self.uploadFileId)",
                    level: .warning
                )
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
            Task {
                try await deleteUploadFile()
            }
        }
    }

    // MARK: - Private methods -

    // MARK: Progress

    /// Returns  the upload progress. Ranges from 0 to 1.
    @discardableResult func updateUploadProgress() -> Double {
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

    // MARK: Network callback

    // Chunk upload network callback
    public func uploadCompletion(data: Data?, response: URLResponse?, error: Error?) {
        enqueueCatching {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            // Success
            if let data,
               error == nil,
               statusCode >= 200, statusCode < 300 {
                try await self.uploadCompletionSuccess(data: data, response: response, error: error)
            }

            // Client-side error
            else if let error {
                try self.uploadCompletionLocalFailure(data: data, response: response, error: error)
            }

            // Server-side error
            else {
                self.uploadCompletionRemoteFailure(data: data, response: response, error: error)
            }
        }
    }

    private func uploadCompletionSuccess(data: Data, response: URLResponse?, error: Error?) async throws {
        Log.uploadOperation("completion successful \(uploadFileId)")

        guard let uploadedChunk = try? DriveApiFetcher.decoder.decode(ApiResponse<UploadedChunk>.self, from: data).data else {
            Log.uploadOperation("parsing error:\(String(describing: error)) ufid:\(uploadFileId)", level: .error)
            throw ErrorDomain.parseError
        }
        Log.uploadOperation("completion chunk:\(uploadedChunk.number)  ufid:\(uploadFileId)")

        try transactionWithChunk(number: uploadedChunk.number) { chunkTask in
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

                let context = ["Chunk number": uploadedChunk.number, "fid": self.uploadFileId]
                SentryDebug.capture(message: "Missing chunk identifier", context: context, contextKey: "Chunk Infos")

                // We may be running both the app and the extension
                assertionFailure("unable to lookup chunk task id, ufid:\(self.uploadFileId)")
            }

            // Cleanup chunks in storage
            if let path = chunkTask.path {
                let url = URL(fileURLWithPath: path, isDirectory: false)
                let chunkNumber = chunkTask.chunkNumber
                Log.uploadOperation("cleanup chunk:\(chunkNumber) ufid:\(self.uploadFileId)")
                do {
                    try self.fileManager.removeItem(at: url)
                } catch {
                    Log.uploadOperation("failed to clean chunk \(error) ufid:\(self.uploadFileId)", level: .error)
                }
            }
        } notFound: {
            Log.uploadOperation("matching chunk:\(uploadedChunk.number) failed ufid:\(self.uploadFileId)", level: .error)
            let context = ["Chunk number": uploadedChunk.number, "fid": self.uploadFileId]
            SentryDebug.capture(message: "Upload matching chunk failed", context: context, contextKey: "Chunk Infos")

            throw ErrorDomain.unableToMatchUploadChunk
        }

        // Update UI progress state
        updateUploadProgress()

        // Decide if we should send the complete call, do next chunk, or retry the upload
        enqueueTryFinishOrEnqueueNextChunk()
    }

    private func uploadCompletionLocalFailure(data: Data?, response: URLResponse?, error: Error) throws {
        Log.uploadOperation("completion Client-side error:\(error) ufid:\(uploadFileId)", level: .error)
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            handleLocalErrors(error: error)
            end()
            return
        }

        switch nsError.code {
        case NSURLErrorCancelled, NSURLErrorNetworkConnectionLost:
            /// Here a Chunk request canceled on .taskRescheduled _or_ the network connection was lost
            /// Either way we catch silently the issue, the operation will seamlessly retry the chunk
            var iterator = uploadTasks.makeIterator()
            try cleanUploadSessionUploadTaskNotUploading(iterator: &iterator)

            // Decide if we should send the complete call, do next chunk, or retry the upload
            enqueueTryFinishOrEnqueueNextChunk()

            return
        default:
            handleLocalErrors(error: error)
            end()
        }
    }

    private func uploadCompletionRemoteFailure(data: Data?, response: URLResponse?, error: Error?) {
        // Silent handling if error if cancel error
        guard let nsError = error as? NSError,
              nsError.code == NSURLErrorCancelled else {
            return
        }

        defer {
            end()
        }

        if let data {
            Log.uploadOperation(
                "uploadCompletionRemoteFailure dataString:\(String(decoding: data, as: UTF8.self)) ufid:\(uploadFileId)",
                level: .error
            )
        }

        var driveError = DriveError.serverError
        if let data,
           let apiError = try? DriveApiFetcher.decoder.decode(ApiResponse<Empty>.self, from: data).error {
            driveError = DriveError(apiError: apiError)
        }

        if let error {
            driveError = driveError.wrapping(error)
        }

        Log.uploadOperation("completion  Server-side error:\(driveError) ufid:\(uploadFileId) ", level: .error)
        handleRemoteErrors(error: driveError)
    }

    // MARK: Misc

    /// Decide if we should send the complete call, do next chunk, or retry the upload
    private func enqueueTryFinishOrEnqueueNextChunk() {
        enqueueCatching {
            // Decide if we should send the complete call or retry the upload
            try await self.completeUploadSessionOrRetryIfPossible()

            // Follow up with chunking again
            if self.availableWorkerSlots() > 0 {
                try await self.generateChunksAndFanOutIfNeeded()
            }
        }
    }

    /// Propagate the newly uploaded DriveFile / File into the specialized Realms
    func handleDriveFilePostUpload(_ driveFile: File) throws {
        let readOnlyFile = try readOnlyFile()
        let driveId = readOnlyFile.driveId
        let userId = readOnlyFile.userId
        @InjectService var appContext: AppContextServiceable

        // Get a DriveFileManager specific to current context
        let driveFileManager: DriveFileManager?
        if appContext.context == .fileProviderExtension {
            driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId)?
                .instanceWith(context: .fileProvider)
        } else {
            driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId)
        }

        // Add/Update the new remote `File` in database immediately
        if let driveFileManager {
            try? driveFileManager.database.writeTransaction { writableRealm in
                let parentFolder = writableRealm.objects(File.self)
                    .filter("id == %@", driveFile.parentId)
                    .first

                writableRealm.add(driveFile, update: .modified)

                // Make sure the parent folder state is consistent, if available
                parentFolder?.children.insert(driveFile)
            }
        }

        // Update the UploadFile to reflect the upload is finished
        // This will generate events threw observation
        try transactionWithFile { file in
            file.uploadDate = Date()
            file.remoteFileId = driveFile.id
            file.uploadingSession = nil // For the sake of keeping the Realm small
            file.error = nil
        }

        result.driveFile = File(value: driveFile)
    }
}
