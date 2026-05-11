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
    /// Compute SHA256 hash for chunks that need it, then fan out for upload.
    /// This optimized version reads directly from the source file without writing temporary chunk files.
    func generateChunksAndFanOutIfNeeded() async throws {
        Log.uploadOperation("generateChunksAndFanOutIfNeeded ufid:\(uploadFileId)")
        try checkCancelation()
        try checkForRestrictedUploadOverDataMode()

        var filePath = ""
        var chunksToGenerateCount = 0
        try transactionWithFile { file in
            // Get the current uploading session
            guard let uploadingSessionTask = file.uploadingSession else {
                throw ErrorDomain.uploadSessionTaskMissing
            }

            filePath = file.pathURL?.path ?? ""

            // Look for the next chunk that needs hash computation
            let chunksToGenerate = uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.notDoneUploadingPredicate)
                .filter { !$0.isReadyForUpload }
            guard let chunkTask = chunksToGenerate.first else {
                Log.uploadOperation("generateChunksAndFanOutIfNeeded no remaining chunks to generate ufid:\(self.uploadFileId)")
                return
            }
            Log.uploadOperation("generateChunksAndFanOutIfNeeded working with:\(chunkTask.chunkNumber) ufid:\(self.uploadFileId)")

            chunksToGenerateCount = chunksToGenerate.count
            let chunkNumber = chunkTask.chunkNumber
            let range = chunkTask.range
            let fileUrl = try self.getFileUrlIfReadable(file: file)

            // Read chunk data from source file to compute SHA256 hash
            guard let chunkProvider = ChunkProvider(fileURL: fileUrl, ranges: [range]),
                  let chunkData = chunkProvider.next() else {
                Log.uploadOperation("Unable to get a ChunkProvider for \(self.uploadFileId)", level: .error)
                throw ErrorDomain.chunkError
            }

            Log.uploadOperation(
                "Computing hash for chunk:\(chunkNumber) of \(chunksToGenerateCount) remaining, ufid:\(self.uploadFileId)"
            )

            try self.checkCancelation()

            // Compute and store only the SHA256 hash - no temp file needed
            let chunkSHA256 = chunkData.SHA256DigestString
            chunkTask.sha256 = chunkSHA256

            Log.uploadOperation("Hash computed for chunk:\(chunkNumber) ufid:\(self.uploadFileId)")
        }

        // Schedule next step
        try await scheduleNextChunk(filePath: filePath,
                                    chunksToGenerateCount: chunksToGenerateCount)
    }

    /// Prepare chunk upload requests, and start them.
    private func scheduleNextChunk(filePath: String, chunksToGenerateCount: Int) async throws {
        do {
            try checkCancelation()
            try checkForRestrictedUploadOverDataMode()

            // Fan-out the chunk we just made
            enqueueCatching {
                try await self.fanOutChunks()
            }

            // Chain the next chunk generation if necessary
            let slots = availableWorkerSlots()
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
    /// This optimized version reads chunk data directly from the source file using memory mapping,
    /// avoiding the need to write temporary chunk files to disk.
    func fanOutChunks() async throws {
        try checkCancelation()
        try checkForRestrictedUploadOverDataMode()

        let freeSlots = availableWorkerSlots()
        guard freeSlots > 0 else {
            return
        }

        try transactionWithFile { file in
            // Get the current uploading session
            guard let uploadingSessionTask: UploadingSessionTask = file.uploadingSession else {
                Log.uploadOperation("fanOut no session task for:\(self.uploadFileId)", level: .error)
                throw ErrorDomain.uploadSessionTaskMissing
            }

            guard let uploadSession = uploadingSessionTask.uploadSession else {
                Log.uploadOperation("fanOut no session for:\(self.uploadFileId)", level: .error)
                throw ErrorDomain.uploadSessionTaskMissing
            }

            let chunksToUpload = Array(uploadingSessionTask.chunkTasks
                .filter(UploadingChunkTask.canStartUploadingPreconditionPredicate)
                .filter { $0.isReadyForUpload })
                .prefix(freeSlots) // Iterate over only the available worker slots

            Log.uploadOperation("fanOut chunksToUpload:\(chunksToUpload.count) freeSlots:\(freeSlots) for:\(self.uploadFileId)")

            // Access Token must be added for non AF requests
            let accessToken = self.accountManager.getTokenForUserId(file.userId)?.accessToken
            guard let accessToken else {
                Log.uploadOperation("no access token found", level: .error)
                throw ErrorDomain.unableToBuildRequest
            }

            // Get the source file URL for reading chunk data
            let sourceFileUrl = try self.getFileUrlIfReadable(file: file)

            // Memory-map the source file for efficient chunk reading
            let mappedFileData: Data
            do {
                mappedFileData = try Data(contentsOf: sourceFileUrl, options: .mappedIfSafe)
            } catch {
                Log.uploadOperation("Failed to memory-map source file: \(error) ufid:\(self.uploadFileId)", level: .error)
                throw error
            }

            // Schedule all the chunks to be uploaded
            for chunkToUpload: UploadingChunkTask in chunksToUpload {
                try self.checkCancelation()

                do {
                    guard let sha256 = chunkToUpload.sha256 else {
                        throw ErrorDomain.missingChunkHash
                    }

                    let chunkHashHeader = "sha256:\(sha256)"
                    let chunkNumber = chunkToUpload.chunkNumber
                    let chunkSize = chunkToUpload.chunkSize
                    let range = chunkToUpload.range

                    // Extract chunk data directly from memory-mapped source file
                    let startIndex = Int(range.lowerBound)
                    let endIndex = Int(range.upperBound) + 1 // upperBound is inclusive in DataRange
                    guard startIndex >= 0, endIndex <= mappedFileData.count else {
                        Log.uploadOperation(
                            "Chunk range out of bounds: \(range) for file size \(mappedFileData.count) ufid:\(self.uploadFileId)",
                            level: .error
                        )
                        throw ErrorDomain.chunkError
                    }
                    let chunkData = mappedFileData[startIndex ..< endIndex]

                    let request = try self.buildRequest(chunkNumber: chunkNumber,
                                                        chunkSize: chunkSize,
                                                        chunkHash: chunkHashHeader,
                                                        sessionToken: uploadingSessionTask.token,
                                                        driveId: file.driveId,
                                                        accessToken: accessToken,
                                                        host: uploadSession.uploadHost)

                    // Upload directly from memory-mapped data slice - no temp file needed
                    let uploadTask = self.urlSession.uploadTask(with: request,
                                                                from: chunkData,
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
