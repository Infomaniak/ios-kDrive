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
import Sentry

extension UploadOperation {
    /// Enqueue a task, while making sure we catch the errors in a standard way
    func enqueueCatching(asap: Bool = false, _ task: @escaping () async throws -> Void) {
        enqueue(asap: asap) {
            await self.catching {
                try await task()
            }
        }
    }

    /// Global UploadOperation error handling
    func catching(_ task: @escaping () async throws -> Void) async {
        do {
            try await task()
        } catch {
            defer {
                end()
            }

            // error tracking
            Log.uploadOperation("catching error:\(error) ufid:\(uploadFileId)", level: .error)
            sentryTrackingError(error)

            // error handling
            if !handleLocalErrors(error: error) {
                handleRemoteErrors(error: error)
            }

            return
        }
    }

    // MARK: - Local Errors

    @discardableResult
    func handleLocalErrors(error: Error) -> Bool {
        var errorHandled = false
        try? transactionWithFile { file in
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                Log.uploadOperation("NSURLError:\(error) ufid:\(self.uploadFileId)")
                file.error = .networkError
                errorHandled = true
            }

            // Do nothing on taskRescheduled
            else if let error = error as? DriveError, error == .taskRescheduled {
                file.error = .taskRescheduled
                errorHandled = true
            }

            // Local file has been removed, delete the operation
            else if let error = error as? DriveError, error == .fileNotFound {
                file.maxRetryCount = 0
                file.progress = nil
                file.error = DriveError.taskCancelled // cascade deletion
                errorHandled = true
            }

            // Not enough space
            else if case .notEnoughSpace = error as? FreeSpaceService.StorageIssues {
                self.uploadNotifiable.sendNotEnoughSpaceForUpload(filename: file.name)
                self.uploadQueue.suspendAllOperations()
                file.maxRetryCount = 0
                file.progress = nil
                file.error = DriveError.errorDeviceStorage.wrapping(error)
                errorHandled = true
            }

            // specialized local errors
            else if let error = error as? UploadOperation.ErrorDomain {
                switch error {
                case .unableToBuildRequest:
                    file.error = DriveError.localError.wrapping(error)

                case .unableToMatchUploadChunk,
                     .splitError,
                     .chunkError,
                     .fileIdentityHasChanged,
                     .parseError,
                     .missingChunkHash:
                    self.cleanUploadFileSession(file: file)
                    file.error = DriveError.localError.wrapping(error)

                case .uploadSessionTaskMissing,
                     .uploadSessionInvalid:
                    self.cleanUploadFileSession(file: file)
                    file.error = DriveError.localError.wrapping(error)

                case .operationFinished, .operationCanceled:
                    Log.uploadOperation("catching operation is terminating")
                    // the operation is terminating, silent handling

                case .databaseUploadFileNotFound:
                    // Silently stop if an UploadFile is no longer in base
                    self.cancel()
                }

                errorHandled = true
            } else {
                // Other DriveError
                file.error = error as? DriveError
                errorHandled = false
            }
        }
        return errorHandled
    }

    // MARK: - Remote Errors

    @discardableResult
    func handleRemoteErrors(error: Error) -> Bool {
        guard let error = error as? DriveError, (error.type == .networkError) || (error.type == .serverError) else {
            Log.uploadOperation("error:\(error) not a remote one ufid:\(uploadFileId)")
            return false
        }

        var errorHandled = false
        try? transactionWithFile { file in
            defer {
                Log.uploadOperation("catching remote error:\(error) ufid:\(self.uploadFileId)", level: .error)
                file.error = error
            }

            switch error {
            case .fileAlreadyExistsError:
                file.maxRetryCount = 0
                file.progress = nil

            case .lock, .notAuthorized:
                self.cleanUploadFileSession(file: file)
                file.progress = nil

            case .productMaintenance, .driveMaintenance:
                // We stop and hope the maintenance is finished at next execution
                self.uploadQueue.suspendAllOperations()

            case .quotaExceeded:
                file.error = DriveError.quotaExceeded
                file.maxRetryCount = 0
                file.progress = nil
                self.uploadQueue.suspendAllOperations()

            case .uploadNotTerminatedError,
                 .uploadNotTerminated,
                 .invalidUploadTokenError,
                 .uploadError,
                 .uploadFailedError,
                 .uploadTokenIsNotValid:
                self.cleanUploadFileSession(file: file)
                file.progress = nil

            case .uploadTokenCanceled:
                // We cancelled the upload session, running chunks requests are failing
                file.progress = nil

            case .objectNotFound, .uploadDestinationNotFoundError, .uploadDestinationNotWritableError:
                // If we get an ”object not found“ error, we cancel all further uploads in this folder
                file.maxRetryCount = 0
                file.progress = nil
                self.cleanUploadFileSession(file: file)
                self.uploadQueue.cancelAllOperations(withParent: file.parentDirectoryId,
                                                     userId: file.userId,
                                                     driveId: file.driveId)

                if self.photoLibraryUploader.isSyncEnabled
                    && self.photoLibraryUploader.settings?.parentDirectoryId == file.parentDirectoryId {
                    self.photoLibraryUploader.disableSync()
                    self.notificationHelper.sendPhotoSyncErrorNotification()
                }

            case .networkError:
                file.error = error
                self.cancel()

            default:
                // simple retry
                break
            }

            errorHandled = true
        }

        return errorHandled
    }

    // MARK: - Private

    private func sentryTrackingError(_ error: Error) {
        // We capture the error with a detailed state of the upload task for debugging purposes.
        SentrySDK.capture(error: error) { scope in
            do {
                try self.transactionWithFile { file in
                    var metadata: [String: Any] = ["uploadFileId": self.uploadFileId,
                                                   "uploadDate": file.uploadDate ?? "nil",
                                                   "creationDate": file.creationDate ?? "nil",
                                                   "modificationDate": file.modificationDate ?? "nil",
                                                   "taskCreationDate": file.taskCreationDate ?? "nil",
                                                   "progress": file.progress ?? 0,
                                                   "initiatedFromFileManager": file.initiatedFromFileManager,
                                                   "maxRetryCount": file.maxRetryCount,
                                                   "rawPersistedError": file._error ?? "nil"]
                    // Unwrap uploadingSession
                    guard let session = file.uploadingSession else {
                        metadata["uploadingSession"] = "nil"
                        scope.setExtras(metadata)
                        return
                    }

                    // Log chunkTasks status
                    let chunkTasks = session.chunkTasks
                    let chunkTaskCount = chunkTasks.count
                    metadata["chunkTasks.count"] = chunkTaskCount
                    for (index, object) in chunkTasks.enumerated() {
                        metadata["chunkTask-\(index)-error"] = object.error
                        metadata["chunkTask-\(index)-chunk"] = object.chunk
                        metadata["chunkTask-\(index)-chunkNumber"] = object.chunkNumber
                    }

                    // Log uploadSession status
                    guard let uploadSession = session.uploadSession else {
                        metadata["file.uploadingSession.uploadSession"] = "nil"
                        scope.setExtras(metadata)
                        return
                    }

                    // Log uploadingSession.uploadSession state
                    metadata["file.uploadingSession.uploadSession"] =
                        "result:\(uploadSession.result) - token:\(uploadSession.token)"

                    scope.setExtras(metadata)
                }
            } catch {
                let metadata = ["ErrorFetchingUploadFile": error]
                scope.setExtras(metadata)
            }
        }
    }
}
