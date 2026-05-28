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
    /// Prepare chunk upload requests, and start them.
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
                .filter(UploadingChunkTask.canStartUploadingPreconditionPredicate))
                .prefix(freeSlots) // Iterate over only the available worker slots

            Log.uploadOperation("fanOut chunksToUpload:\(chunksToUpload.count) freeSlots:\(freeSlots) for:\(self.uploadFileId)")

            // Access Token must be added for non AF requests
            let accessToken = self.accountManager.getTokenForUserId(file.userId)?.accessToken
            guard let accessToken else {
                Log.uploadOperation("no access token found", level: .error)
                throw ErrorDomain.unableToBuildRequest
            }

            let sourceFileUrl = try self.getFileUrlIfReadable(file: file)

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
                    let chunkHashHeader = "sha256:\(chunkData.SHA256DigestString)"

                    let request = try self.buildRequest(chunkNumber: chunkNumber,
                                                        chunkSize: chunkSize,
                                                        chunkHash: chunkHashHeader,
                                                        sessionToken: uploadingSessionTask.token,
                                                        driveId: file.driveId,
                                                        accessToken: accessToken,
                                                        host: uploadSession.uploadHost)

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
