/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import Sentry

// MARK: - Session management -

extension UploadOperation {
    // MARK: Session Validation

    /// Refresh or create something that represents the state of the upload, and store it to the current UploadFile
    func refreshUploadSessionOrCreate() async throws {
        try checkCancelation()
        try freeSpaceService.checkEnoughAvailableSpaceForChunkUpload()

        // Set progress to zero if needed
        updateUploadProgress()
        defer {
            // Update progress once the session was created
            updateUploadProgress()
        }

        Log.uploadOperation("Asking for an upload Session ufid:\(uploadFileId)")

        let uploadId = uploadFileId
        var uploadingSession: UploadingSessionTask?
        var error: ErrorDomain?
        try transactionWithFile { file in
            SentryDebug.uploadOperationRetryCountDecreaseBreadcrumb(uploadId, file.maxRetryCount)

            // If cannot retry, throw
            guard file.maxRetryCount > 0 else {
                error = ErrorDomain.retryCountIsZero
                return
            }

            // Decrease retry count
            file.maxRetryCount -= 1
            Log.uploadOperation("retry count is now:\(file.maxRetryCount) ufid:\(self.uploadFileId)")

            uploadingSession = file.uploadingSession?.detached()
        }

        if let error {
            throw error
        }

        // Local session check
        guard let uploadingSession, !uploadingSession.isExpired else {
            try await wipeSessionAndRegenerate()
            return
        }

        // Try to reuse session by negotiation with server
        do {
            // Check session state with server
            let localStateIsValid = try await validateSessionStateWithServer()
            Log.uploadOperation("localStateIsValid :\(localStateIsValid) ufid:\(uploadFileId)")

            // Something prevents reuse of session, we restart
            guard localStateIsValid else {
                throw ErrorDomain.uploadSessionInvalid
            }

            // All good, clean the previous state before we restart
            try await fetchAndCleanStoredSessionForReuse()
        }
        // Local error handling if issue with fetching remote session
        catch {
            // Log all session negotiation in one place
            sentryTrackingSessionError(error)

            // Server does not know of the session
            if let driveError = error as? DriveError,
               driveError == DriveError.invalidUploadTokenError {
                try await wipeSessionAndRegenerate()
            }

            // Client failed to validate the session with the server
            else if let domainError = error as? ErrorDomain,
                    domainError == ErrorDomain.uploadSessionInvalid {
                try await wipeSessionAndRegenerate()
            }

            // The local session was removed
            else if let domainError = error as? ErrorDomain,
                    domainError == ErrorDomain.uploadSessionTaskMissing {
                try await wipeSessionAndRegenerate()
            }

            // Unable to recover, generic error handling
            else {
                throw error
            }
        }
    }

    private func wipeSessionAndRegenerate() async throws {
        await cleanUploadFileSession()
        try await generateNewSessionAndStore()
    }

    private func validateSessionStateWithServer() async throws -> Bool {
        Log.uploadOperation("validate liveSession ufid:\(uploadFileId)")

        try checkCancelation()
        let file = try readOnlyFile()
        guard let uploadingSessionTask = file.uploadingSession else {
            throw ErrorDomain.uploadSessionTaskMissing
        }
        let sessionToken = AbstractTokenWrapper(token: uploadingSessionTask.token)
        let driveFileManager = try getDriveFileManager(for: file.driveId, userId: file.userId)
        let drive = driveFileManager.drive
        let liveSession = try await driveFileManager.apiFetcher.getSession(
            drive: drive,
            sessionToken: sessionToken
        )

        // Try to recover if we failed to fetch a success callback on a chunk request
        if let localChunkSuccessCount = try? chunkTasksDoneUploadingSuccessCount(),
           liveSession.receivedChunks != localChunkSuccessCount {
            Log.uploadOperation("mismatch 📡\(liveSession.receivedChunks) != 📲\(localChunkSuccessCount)")
            let distantChunksInSuccess = liveSession.chunks.filter { $0.isValidUpload }

            // Try to insert the chunks in success into the session
            try? transactionWithFile { file in
                guard let uploadingSessionTask = file.uploadingSession else {
                    return
                }

                file.error = nil

                for distantChunk in distantChunksInSuccess {
                    let distantNumber = distantChunk.number
                    guard let chunkTask = uploadingSessionTask.chunkTasks.first(where: { $0.chunkNumber == distantNumber }) else {
                        Log.uploadOperation("mismatch unable to resolve :\(distantNumber)", level: .error)
                        return
                    }

                    chunkTask.chunk = distantChunk.toRealmObject()
                    chunkTask.taskIdentifier = nil
                    chunkTask.error = nil
                }
            }
        }

        // compare local state
        let chunkTasksTotalCount = try chunkTasksTotalCount()
        let chunkTasksDoneUploadingSuccessCount = try chunkTasksDoneUploadingSuccessCount()
        let chunkTasksInErrorCount = try chunkTasksInErrorCount()

        guard liveSession.expectedChunks == chunkTasksTotalCount,
              liveSession.receivedChunks == chunkTasksDoneUploadingSuccessCount,
              liveSession.uploadingChunks == 0 else {
            Log.uploadOperation("""
                                Session mismatch with server after a merging remote state
                                expectedChunks:📡\(liveSession.expectedChunks):📲\(chunkTasksTotalCount)
                                receivedChunks:📡\(liveSession.receivedChunks):📲\(chunkTasksDoneUploadingSuccessCount)
                                uploadingChunks:📡\(liveSession.uploadingChunks):📲\(0)
                                failedChunks:📡\(liveSession.failedChunks):📲\(chunkTasksInErrorCount)
                                ufid:\(uploadFileId)
                                """,
                                level: .error)

            return false
        }

        return true
    }

    /// Complete the upload if needed, or retry if `maxRetryCount` has not reached zero
    func completeUploadSessionOrRetryIfPossible() async throws {
        try checkCancelation()

        // Close session and terminate task as the last chunk was uploaded
        let chunksToUploadCount = try chunkTasksToUploadCount()
        let chunksInErrorCount = try chunkTasksInErrorCount()
        Log.uploadOperation(
            "completion upload state: chunksToUploadCount:\(chunksToUploadCount) chunksInErrorCount:\(chunksInErrorCount) fid:\(uploadFileId)"
        )

        if chunksToUploadCount == 0, chunksInErrorCount == 0 {
            Log.uploadOperation("No more chunks to be uploaded \(uploadFileId)")
            try await closeSessionAndEnd()
        }

        // We should retry some chunks in failed state
        else if chunksToUploadCount == 0 && chunksInErrorCount != 0 {
            // fetch specific chunk errors
            var errors: [Error] = []
            var maxOperationRetryCount = 0
            try transactionWithFile { file in
                maxOperationRetryCount = file.maxRetryCount
                if let chunkTasksInError = file.uploadingSession?.chunkTasks.filter(UploadingChunkTask.inErrorPredicate) {
                    errors = chunkTasksInError.compactMap { $0.error }
                }

                // Decrease retry count
                if file.maxRetryCount > 0 {
                    file.maxRetryCount -= 1
                }
            }

            SentryDebug.uploadOperationChunkInFailureCannotCloseSessionBreadcrumb(
                uploadFileId,
                [
                    "chunksTasksPending": uploadTasks.count,
                    "chunksInErrorCount": chunksInErrorCount,
                    "maxOperationRetryCount": maxOperationRetryCount,
                    "errors": errors
                ]
            )

            // If cannot retry, throw error
            guard maxOperationRetryCount > 0 else {
                throw ErrorDomain.retryCountIsZero
            }

            // Sanity stop all remaining network requests
            cancelAllUploadRequests()

            // We can retry, so clean the chunks linked to a session and retry upload
            try await fetchAndCleanStoredSessionForReuse()
        }
    }

    /// Close session if needed.
    private func closeSessionAndEnd() async throws {
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
            let driveFile = File(value: uploadedFile.file)

            Log.uploadOperation("uploadedFile 'File' id:\(driveFile.id) ufid:\(self.uploadFileId)")
            try self.handleDriveFilePostUpload(driveFile)
        }
    }

    public func cleanUploadFileSession() async {
        Log.uploadOperation("Clean session for \(uploadFileId)")
        SentryDebug.uploadOperationCleanSessionBreadcrumb(uploadFileId)

        if let readOnlyFile = try? readOnlyFile(),
           readOnlyFile.uploadingSession != nil {
            await cleanUploadFileSessionRemotely(readOnlyFile: readOnlyFile)
        }
        cleanUploadFileSessionLocally()

        cancelAllUploadRequests()
    }

    private func cleanUploadFileSessionRemotely(readOnlyFile: UploadFile) async {
        // Clean the remote session, if any. Invalid ones are already gone server side.
        guard let token = readOnlyFile.uploadingSession?.token else {
            return
        }

        let driveId = readOnlyFile.driveId
        let userId = readOnlyFile.userId
        await cleanRemoteSession(AbstractTokenWrapper(token: token), driveId: driveId, userId: userId)
    }

    /// Delete a remote session for a specific token
    private func cleanRemoteSession(_ abstractToken: AbstractToken, driveId: Int, userId: Int) async {
        guard let driveFileManager = try? getDriveFileManager(for: driveId, userId: userId) else {
            return
        }

        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive

        // We try to cancel the upload session, we discard results
        let cancelResult = try? await apiFetcher.cancelSession(drive: drive, sessionToken: abstractToken)
        Log.uploadOperation("cancelSession remotely:\(String(describing: cancelResult)) for \(uploadFileId)")
        SentryDebug.uploadOperationCleanSessionRemotelyBreadcrumb(uploadFileId, cancelResult ?? false)
    }

    /// fetch and clean stored session
    private func fetchAndCleanStoredSessionForReuse() async throws {
        Log.uploadOperation("fetchAndCleanStoredSession ufid:\(uploadFileId)")
        try transactionWithFile { file in
            guard let uploadingSession = file.uploadingSession,
                  !uploadingSession.isExpired else {
                throw ErrorDomain.uploadSessionInvalid
            }

            // Cleanup the uploading chunks and session state for re-use
            let chunkTasksToClean = uploadingSession.chunkTasks.filter(UploadingChunkTask.toRetryPredicate)
            for uploadingChunkTask in chunkTasksToClean {
                uploadingChunkTask.sessionIdentifier = nil
                uploadingChunkTask.taskIdentifier = nil
                uploadingChunkTask.requestUrl = nil
                uploadingChunkTask.path = nil
                uploadingChunkTask.sha256 = nil
                uploadingChunkTask.error = nil
            }

            // Cleanup upload error as we restart
            file.error = nil
        }

        // if we have no more chunks to upload, try to close session
        try await completeUploadSessionOrRetryIfPossible()

        // We have a valid upload session
    }

    /// generate a new session
    private func generateNewSessionAndStore() async throws {
        Log.uploadOperation("generateNewSession ufid:\(uploadFileId)")
        try checkCancelation()

        let file = try readOnlyFile()

        // Check file is readable
        let fileUrl = try getFileUrlIfReadable(file: file)
        let fileSize = try fileSize(fileUrl: fileUrl)

        let mebibytes = String(format: "%.2f", BinaryDisplaySize.bytes(fileSize).toMebibytes)
        Log.uploadOperation("got fileSize:\(mebibytes)MiB ufid:\(uploadFileId)")

        // Compute ranges for a file
        let rangeProvider = RangeProvider(fileURL: fileUrl, config: Constants.rangeProviderConfig)
        let ranges: [DataRange]
        do {
            ranges = try rangeProvider.allRanges
        } catch {
            Log.uploadOperation("Unable generate ranges error:\(error) for ufid\(uploadFileId)", level: .error)
            throw ErrorDomain.splitError
        }
        Log.uploadOperation("got ranges:\(ranges.count) ufid:\(uploadFileId)")

        // Get a valid APIV2 UploadSession
        let driveFileManager = try getDriveFileManager(for: file.driveId, userId: file.userId)
        let apiFetcher = driveFileManager.apiFetcher
        let drive = driveFileManager.drive

        let session = try await apiFetcher.startSession(drive: drive,
                                                        totalSize: fileSize,
                                                        fileName: file.name,
                                                        totalChunks: ranges.count,
                                                        conflictResolution: file.conflictOption,
                                                        lastModifiedAt: file.modificationDate, // Date override for PHAssets
                                                        createdAt: file.creationDate,
                                                        directoryId: file.parentDirectoryId,
                                                        directoryPath: file.relativePath)
        Log.uploadOperation("New session token:\(session.token) ufid:\(uploadFileId)")
        try transactionWithFile { file in
            // Create an uploading session
            let uploadingSessionTask = UploadingSessionTask()

            // Store the session token asap as a non null ivar
            uploadingSessionTask.token = session.token

            // Store the session
            uploadingSessionTask.uploadSession = session

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

    private func cleanUploadFileSessionLocally() {
        // Clean the local uploading session, as well as error
        try? transactionWithFile { file in
            file.uploadingSession = nil
            file.progress = nil
            file.error = nil
        }
    }
}
