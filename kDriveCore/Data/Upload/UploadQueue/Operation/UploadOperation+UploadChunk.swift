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

extension UploadOperation {
    private struct ChunkUploadContext {
        let chunkNumber: Int64
        let chunkSize: Int64
        let range: DataRange
        let sessionToken: String
        let driveId: Int
        let accessToken: String
        let uploadHost: String
    }

    /// Prepare chunk upload requests, and start them.
    func fanOutChunks() async throws {
        try checkCancelation()
        try checkForRestrictedUploadOverDataMode()

        let mappedFileData = try mappedSourceFileData()
        var didCheckCompletionWithoutReadyChunk = false

        while true {
            try checkCancelation()
            try checkForRestrictedUploadOverDataMode()

            guard let chunkUpload = try nextChunkUploadContext() else {
                try await completeUploadSessionOrRetryIfPossible()
                guard !isFinished else {
                    return
                }

                guard !didCheckCompletionWithoutReadyChunk else {
                    Log.uploadOperation("fanOut no uploadable chunk after completion check for:\(uploadFileId)", level: .error)
                    throw ErrorDomain.unableToMatchUploadChunk
                }

                didCheckCompletionWithoutReadyChunk = true
                continue
            }

            didCheckCompletionWithoutReadyChunk = false
            Log.uploadOperation("fanOut serial chunk:\(chunkUpload.chunkNumber) for:\(uploadFileId)")

            let completion = try await uploadChunkSerially(chunkUpload, mappedFileData: mappedFileData)
            try await processChunkUploadResult(data: completion.data,
                                               response: completion.response,
                                               error: completion.error)

            guard !isFinished else {
                return
            }

            try await completeUploadSessionOrRetryIfPossible()
        }
    }

    private func mappedSourceFileData() throws -> Data {
        let file = try readOnlyFile()
        let sourceFileUrl = try getFileUrlIfReadable(file: file)

        do {
            return try Data(contentsOf: sourceFileUrl, options: .mappedIfSafe)
        } catch {
            Log.uploadOperation("Failed to memory-map source file: \(error) ufid:\(uploadFileId)", level: .error)
            throw error
        }
    }

    private func nextChunkUploadContext() throws -> ChunkUploadContext? {
        var chunkUploadContext: ChunkUploadContext?
        try transactionWithFile { file in
            guard let uploadingSessionTask: UploadingSessionTask = file.uploadingSession else {
                Log.uploadOperation("fanOut no session task for:\(self.uploadFileId)", level: .error)
                throw ErrorDomain.uploadSessionTaskMissing
            }

            guard let uploadSession = uploadingSessionTask.uploadSession else {
                Log.uploadOperation("fanOut no session for:\(self.uploadFileId)", level: .error)
                throw ErrorDomain.uploadSessionTaskMissing
            }

            guard let chunkToUpload = uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.canStartUploadingPreconditionPredicate)
                .first else {
                return
            }

            guard let accessToken = self.accountManager.getTokenForUserId(file.userId)?.accessToken else {
                Log.uploadOperation("no access token found", level: .error)
                throw ErrorDomain.unableToBuildRequest
            }

            chunkUploadContext = ChunkUploadContext(chunkNumber: chunkToUpload.chunkNumber,
                                                    chunkSize: chunkToUpload.chunkSize,
                                                    range: chunkToUpload.range,
                                                    sessionToken: uploadingSessionTask.token,
                                                    driveId: file.driveId,
                                                    accessToken: accessToken,
                                                    uploadHost: uploadSession.uploadHost)
        }

        return chunkUploadContext
    }

    private func uploadChunkSerially(_ chunkUpload: ChunkUploadContext,
                                     mappedFileData: Data) async throws -> ChunkUploadCompletion {
        let range = chunkUpload.range
        let startIndex = Int(range.lowerBound)
        let endIndex = Int(range.upperBound) + 1 // upperBound is inclusive in DataRange
        guard startIndex >= 0, endIndex <= mappedFileData.count else {
            Log.uploadOperation(
                "Chunk range out of bounds: \(range) for file size \(mappedFileData.count) ufid:\(uploadFileId)",
                level: .error
            )
            throw ErrorDomain.chunkError
        }

        let chunkData = mappedFileData[startIndex ..< endIndex]
        let chunkHashHeader = "sha256:\(chunkData.SHA256DigestString)"
        let request = try buildRequest(chunkNumber: chunkUpload.chunkNumber,
                                       chunkSize: chunkUpload.chunkSize,
                                       chunkHash: chunkHashHeader,
                                       sessionToken: chunkUpload.sessionToken,
                                       driveId: chunkUpload.driveId,
                                       accessToken: chunkUpload.accessToken,
                                       host: chunkUpload.uploadHost)

        return try await withCheckedThrowingContinuation { continuation in
            guard self.chunkUploadContinuation == nil else {
                Log.uploadOperation("Unable to start serial upload with an active continuation ufid:\(self.uploadFileId)", level: .error)
                continuation.resume(throwing: ErrorDomain.unableToMatchUploadChunk)
                return
            }

            let uploadTask = self.urlSession.uploadTask(with: request,
                                                        from: chunkData,
                                                        completionHandler: self.uploadCompletion)
            // Extra 512 bytes for request headers
            uploadTask.countOfBytesClientExpectsToSend = Int64(chunkUpload.chunkSize) + 512
            // 5KB is a very reasonable upper bound size for a file server response (max observed: 1.47KB)
            uploadTask.countOfBytesClientExpectsToReceive = 1024 * 5

            let identifier = self.urlSession.identifier(for: uploadTask)
            self.uploadTasks[identifier] = uploadTask

            do {
                try transactionWithChunk(number: chunkUpload.chunkNumber) { chunkTask in
                    chunkTask.sessionIdentifier = self.urlSession.identifier
                    chunkTask.taskIdentifier = identifier
                    chunkTask.requestUrl = request.url?.absoluteString
                } notFound: {
                    Log.uploadOperation(
                        "Unable to match chunk to start for number:\(chunkUpload.chunkNumber) ufid:\(self.uploadFileId)",
                        level: .error
                    )
                    throw ErrorDomain.unableToMatchUploadChunk
                }
            } catch {
                self.uploadTasks.removeValue(forKey: identifier)
                uploadTask.cancel()
                continuation.resume(throwing: error)
                return
            }

            self.chunkUploadContinuation = continuation
            uploadTask.resume()

            Log.uploadOperation("started task identifier:\(identifier) for:\(self.uploadFileId)")
        }
    }

    /// Make sure all `uploadTasks` canceled or completed are up to date in database.
    /// - Parameter iterator: A view on `uploadTasks`
    func cleanUploadSessionUploadTaskNotUploading(iterator: inout Dictionary<String, URLSessionUploadTask>.Iterator) throws {
        while let (taskIdentifier, sessionTask) = iterator.next() {
            Log.uploadOperation(
                "cleanUploadSessionUploadTaskNotUploading taskIdentifier:\(taskIdentifier) sessionTask.state \(sessionTask.state) ufid:\(uploadFileId)"
            )

            switch sessionTask.state {
            case URLSessionTask.State.canceling, URLSessionTask.State.completed:
                try transactionWithChunk(taskIdentifier: taskIdentifier) { chunkTask in
                    // Only edit if no chunk stored in success
                    guard chunkTask.chunk == nil else {
                        return
                    }

                    // Clear tracking fields so the chunk can be retried
                    chunkTask.sessionIdentifier = nil
                    chunkTask.taskIdentifier = nil
                    chunkTask.requestUrl = nil
                    chunkTask.error = .taskRescheduled
                } notFound: {
                    Log.uploadOperation(
                        "Unable to match chunk to reschedule for identifier:\(taskIdentifier) ufid:\(self.uploadFileId)",
                        level: .error
                    )
                }

                // Remove upload session from tracking
                uploadTasks.removeValue(forKey: taskIdentifier)
                return
            default:
                return
            }
        }
    }
}
