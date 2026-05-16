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
    /// Process all remaining chunks of the current upload session sequentially.
    ///
    /// File-level parallelism is achieved by the OperationQueue running multiple
    /// `UploadOperation` instances concurrently. Within a single file we hash and
    /// upload one chunk at a time which removes the need for the previous async
    /// re-entry / fan-out scheduling.
    ///
    /// Chunk data is read directly from the memory-mapped source file, so no
    /// temporary chunk files are written to disk.
    func generateChunksAndFanOutIfNeeded() async throws {
        Log.uploadOperation("processAllChunks ufid:\(uploadFileId)")
        try checkCancelation()
        try checkForRestrictedUploadOverDataMode()

        // Memory-map the source file once for the whole loop.
        let sourceFileUrl: URL
        do {
            let file = try readOnlyFile()
            sourceFileUrl = try getFileUrlIfReadable(file: file)
        }

        let mappedFileData: Data
        do {
            mappedFileData = try Data(contentsOf: sourceFileUrl, options: .mappedIfSafe)
        } catch {
            Log.uploadOperation("Failed to memory-map source file: \(error) ufid:\(uploadFileId)", level: .error)
            throw error
        }

        // Outer loop allows `completeUploadSessionOrRetryIfPossible()` to reset failed
        // chunks back to "to upload" so we can retry them in the same operation.
        repeat {
            // Sequentially process every chunk that is not yet uploaded.
            while try hasChunkRemainingToUpload() {
                try checkCancelation()
                try checkForRestrictedUploadOverDataMode()

                try await processNextChunk(mappedFileData: mappedFileData)
            }

            Log.uploadOperation("Upload pass finished ufid:\(uploadFileId)")

            // Decide if we should send the complete call or schedule a retry.
            // On retry it will reset errored chunks so the outer loop can pick them up again.
            try await completeUploadSessionOrRetryIfPossible()

            // The session may have been closed (success path calls end()). Stop here.
            if isFinished {
                return
            }
        } while try hasChunkRemainingToUpload()
    }

    /// Returns `true` while at least one chunk still needs to be uploaded.
    ///
    /// We perform the count inside a Realm transaction because filtering by `NSPredicate`
    /// is only supported on managed `List` instances. A detached `UploadFile` would crash
    /// with "This method may only be called on RLMArray instances retrieved from an RLMRealm".
    private func hasChunkRemainingToUpload() throws -> Bool {
        var remaining = 0
        try transactionWithFile { file in
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            remaining = uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.notDoneUploadingPredicate)
                .count
        }
        return remaining > 0
    }

    /// Hash and upload the next pending chunk, blocking until the network response is processed.
    private func processNextChunk(mappedFileData: Data) async throws {
        // Pick the next chunk needing work and ensure its hash is computed.
        let chunkNumber = try prepareNextChunkHash(mappedFileData: mappedFileData)

        try checkCancelation()

        // Build the request for that chunk and upload it sequentially.
        let context = try buildChunkUploadContext(
            chunkNumber: chunkNumber,
            mappedFileData: mappedFileData
        )

        let (responseData, response) = try await uploadChunk(
            chunkNumber: chunkNumber,
            request: context.request,
            chunkData: context.chunkData,
            chunkSize: context.chunkSize
        )

        try processChunkResponse(data: responseData, response: response)
    }

    /// Compute and persist the SHA256 hash for the next pending chunk if needed,
    /// then return its chunk number.
    private func prepareNextChunkHash(mappedFileData: Data) throws -> Int64 {
        var resolvedChunkNumber: Int64 = 0
        try transactionWithFile { file in
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            // Realm `Results` use NSPredicate-based filtering; `.first(where:)` is not applicable.
            // swiftlint:disable:next first_where
            guard let chunkTask = uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.notDoneUploadingPredicate)
                .first else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            resolvedChunkNumber = chunkTask.chunkNumber

            // Hash already computed (e.g. resumed session) — nothing to do.
            guard !chunkTask.isReadyForUpload else {
                return
            }

            let range = chunkTask.range
            let chunkData = try self.slice(mappedFileData: mappedFileData, range: range)

            Log.uploadOperation("Computing hash for chunk:\(chunkTask.chunkNumber) ufid:\(self.uploadFileId)")
            try self.checkCancelation()

            chunkTask.sha256 = chunkData.SHA256DigestString
        }
        return resolvedChunkNumber
    }

    /// Per-chunk upload context bundled together so we can return it from a
    /// single Realm transaction.
    private struct ChunkUploadContext {
        let request: URLRequest
        let chunkData: Data
        let chunkSize: Int64
    }

    /// Build the URLRequest, slice the chunk data and return the per-chunk metadata
    /// needed to perform the upload.
    private func buildChunkUploadContext(
        chunkNumber: Int64,
        mappedFileData: Data
    ) throws -> ChunkUploadContext {
        var resultRequest: URLRequest?
        var resultChunkData: Data?
        var resultChunkSize: Int64 = 0

        try transactionWithFile { file in
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }
            guard let uploadSession = uploadingSessionTask.uploadSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            guard let chunkTask = uploadingSessionTask.chunkTasks
                .first(where: { $0.chunkNumber == chunkNumber }) else {
                throw ErrorDomain.unableToMatchUploadChunk
            }

            guard let sha256 = chunkTask.sha256 else {
                throw ErrorDomain.missingChunkHash
            }

            guard let accessToken = self.accountManager.getTokenForUserId(file.userId)?.accessToken else {
                Log.uploadOperation("no access token found ufid:\(self.uploadFileId)", level: .error)
                throw ErrorDomain.unableToBuildRequest
            }

            let chunkData = try self.slice(mappedFileData: mappedFileData, range: chunkTask.range)

            let request = try self.buildRequest(chunkNumber: chunkTask.chunkNumber,
                                                chunkSize: chunkTask.chunkSize,
                                                chunkHash: "sha256:\(sha256)",
                                                sessionToken: uploadingSessionTask.token,
                                                driveId: file.driveId,
                                                accessToken: accessToken,
                                                host: uploadSession.uploadHost)

            resultRequest = request
            resultChunkData = chunkData
            resultChunkSize = chunkTask.chunkSize
        }

        guard let request = resultRequest, let chunkData = resultChunkData else {
            throw ErrorDomain.unableToBuildRequest
        }
        return ChunkUploadContext(request: request, chunkData: chunkData, chunkSize: resultChunkSize)
    }

    /// Perform the actual upload, persist the running task on the chunk and wait
    /// for the response.
    private func uploadChunk(
        chunkNumber: Int64,
        request: URLRequest,
        chunkData: Data,
        chunkSize: Int64
    ) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = self.urlSession.uploadTask(with: request, from: chunkData) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: ErrorDomain.parseError)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            uploadTask.countOfBytesClientExpectsToSend = chunkSize + 512
            uploadTask.countOfBytesClientExpectsToReceive = 1024 * 5

            // Persist task identifiers so we can correlate the response with the chunk.
            do {
                try self.transactionWithChunk(number: chunkNumber) { chunkTask in
                    chunkTask.sessionIdentifier = self.urlSession.identifier
                    chunkTask.taskIdentifier = self.urlSession.identifier(for: uploadTask)
                    chunkTask.requestUrl = request.url?.absoluteString
                } notFound: {
                    Log.uploadOperation(
                        "Unable to persist task identifier for chunk:\(chunkNumber) ufid:\(self.uploadFileId)",
                        level: .error
                    )
                }
            } catch {
                continuation.resume(throwing: error)
                return
            }

            currentUploadTask = uploadTask
            Log.uploadOperation("started chunk:\(chunkNumber) ufid:\(self.uploadFileId)")
            uploadTask.resume()
        }
    }

    /// Slice a chunk out of the memory-mapped source file checking range bounds.
    private func slice(mappedFileData: Data, range: DataRange) throws -> Data {
        let startIndex = Int(range.lowerBound)
        let endIndex = Int(range.upperBound) + 1 // upperBound is inclusive in DataRange
        guard startIndex >= 0, endIndex <= mappedFileData.count else {
            Log.uploadOperation(
                "Chunk range out of bounds: \(range) for file size \(mappedFileData.count) ufid:\(uploadFileId)",
                level: .error
            )
            throw ErrorDomain.chunkError
        }
        return mappedFileData[startIndex ..< endIndex]
    }
}
