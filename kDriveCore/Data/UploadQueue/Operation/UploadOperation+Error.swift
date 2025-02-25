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
    /// Enqueue a task, while making sure we catch the errors in a standard way
    func enqueueCatching(_ task: @escaping () async throws -> Void) {
        enqueue {
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
            sentryTrackingUploadError(error)

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
            Log.uploadOperation("NSURLError:\(error) ufid:\(self.uploadFileId)")

            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorCancelled:
                    // System/user cancelled requests silently handled, some chunk upload in error for eg.
                    errorHandled = true
                    // _not_ overriding file.error
                    return
                default:
                    // Any other networking error, including NSURLErrorNetworkConnectionLost,
                    // on any call other than chunks gets a user facing network error.
                    file.error = .networkError.wrapping(error)
                    errorHandled = true
                }
            }

            // Do nothing on taskRescheduled
            else if let error = error as? DriveError, error == .taskRescheduled {
                file.error = .taskRescheduled.wrapping(error)
                errorHandled = true
            }

            // Local file has been removed, delete the operation
            else if let error = error as? DriveError, error == .fileNotFound {
                file.maxRetryCount = 0
                file.progress = nil
                file.error = .taskCancelled.wrapping(error) // cascade deletion
                errorHandled = true
            }

            // Not enough space
            else if case .notEnoughSpace = error as? FreeSpaceService.StorageIssues {
                self.uploadQueue.suspendAllOperations()
                file.maxRetryCount = 0
                file.progress = nil
                file.error = .errorDeviceStorage.wrapping(error)
                errorHandled = true
            }

            // specialized local errors
            else if let error = error as? UploadOperation.ErrorDomain {
                switch error {
                case .unableToBuildRequest:
                    file.error = .localError.wrapping(error)

                case .unableToMatchUploadChunk,
                     .splitError,
                     .chunkError,
                     .parseError,
                     .missingChunkHash,
                     .retryCountIsZero,
                     .uploadSessionTaskMissing,
                     .uploadSessionInvalid:
                    // Clean session, present error, user action required to restart.
                    Task {
                        await self.cleanUploadFileSession()
                    }
                    file.error = .localError.wrapping(error)

                case .operationFinished, .operationCanceled:
                    Log.uploadOperation("catching operation is terminating")
                    // the operation is terminating, silent handling
                    // _not_ overriding file.error

                case .databaseUploadFileNotFound:
                    // Silently stop if an UploadFile is no longer in base
                    // _not_ overriding file.error
                    self.cancel()

                case .uploadOverDataRestrictedError:
                    file.error = DriveError.uploadOverDataRestrictedError
                    self.uploadQueue.suspendAllOperations()
                }

                errorHandled = true
            }

            // other DriveError
            else {
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
            }

            switch error {
            case .fileAlreadyExistsError:
                file.maxRetryCount = 0
                file.progress = nil
                file.error = error

            case .lock, .notAuthorized:
                // simple retry
                file.error = error

            case .productMaintenance, .driveMaintenance:
                // We stop and hope the maintenance is finished at next execution
                file.error = error
                self.uploadQueue.suspendAllOperations()

            case .quotaExceeded:
                file.error = .quotaExceeded.wrapping(error)
                file.maxRetryCount = 0
                file.progress = nil
                self.uploadQueue.suspendAllOperations()

            case .uploadNotTerminatedError,
                 .uploadNotTerminated,
                 .invalidUploadTokenError,
                 .uploadError,
                 .uploadFailedError,
                 .uploadTokenIsNotValid:
                Task {
                    await self.cleanUploadFileSession()
                }
                file.progress = nil
                file.error = error

            case .uploadTokenCanceled:
                // We cancelled the upload session, running chunks requests are failing
                file.progress = nil
                // _not_ overriding file.error

            case .objectNotFound, .uploadDestinationNotFoundError, .uploadDestinationNotWritableError:
                // If we get an ”object not found“ error, we cancel all further uploads in this folder
                file.maxRetryCount = 0
                file.progress = nil
                file.error = error
                Task {
                    await self.cleanUploadFileSession()
                }
                self.uploadQueue.cancelAllOperations(withParent: file.parentDirectoryId,
                                                     userId: file.userId,
                                                     driveId: file.driveId)

                if self.photoLibraryUploader.isSyncEnabled,
                   self.photoLibraryUploader.frozenSettings?.parentDirectoryId == file.parentDirectoryId {
                    self.photoLibraryUploader.disableSync()
                    self.notificationHelper.sendPhotoSyncErrorNotification()
                }

            case .networkError:
                // simple retry
                file.error = error

            default:
                // simple retry
                file.error = error
            }

            errorHandled = true
        }

        return errorHandled
    }

    // MARK: - Private

    /// Common tracking upload error with detailed state of the upload operation
    private func sentryTrackingUploadError(_ error: Error) {
        let metadata = errorMetadata(error)
        SentryDebug.uploadOperationErrorHandling(SentryDebug.ErrorNames.uploadErrorHandling, error, metadata)
    }

    /// Dedicated session generation error with detailed state of the upload operation
    func sentryTrackingSessionError(_ error: Error) {
        let metadata = errorMetadata(error)
        SentryDebug.uploadOperationErrorHandling(SentryDebug.ErrorNames.uploadSessionErrorHandling, error, metadata)
    }

    /// Get a debug representation of the upload operation
    private func errorMetadata(_ error: Error) -> [String: Any] {
        var metadata: [String: Any] = ["version": 5,
                                       "uploadFileId": uploadFileId,
                                       "RootError": error,
                                       "RootError.localizedDescription": error.localizedDescription]

        guard let file = try? readOnlyFile() else {
            metadata["uploadingFile"] = "nil"
            return metadata
        }

        guard !file.isInvalidated else {
            metadata["uploadingFile"] = "isInvalidated"
            return metadata
        }

        metadata["uploadDate"] = file.uploadDate ?? "nil"
        metadata["creationDate"] = file.creationDate ?? "nil"
        metadata["modificationDate"] = file.modificationDate ?? "nil"
        metadata["taskCreationDate"] = file.taskCreationDate ?? "nil"
        metadata["progress"] = file.progress ?? 0
        metadata["ownedByFileProvider"] = file.ownedByFileProvider
        metadata["maxRetryCount"] = file.maxRetryCount
        metadata["rawPersistedError"] = file._error ?? "nil"

        // Unwrap uploadingSession
        guard let sessionTask = file.uploadingSession else {
            metadata["uploadingSession"] = "nil"
            return metadata
        }

        guard !sessionTask.isInvalidated else {
            metadata["uploadingSession"] = "isInvalidated"
            return metadata
        }

        // Log chunkTasks status
        let chunkTasks = sessionTask.chunkTasks
        let chunkTaskCount = chunkTasks.count
        metadata["file.uploadingSession.chunkTasks.count"] = chunkTaskCount
        for (index, object) in chunkTasks.enumerated() {
            guard !object.isInvalidated else {
                metadata["chunkTask-\(index)"] = "isInvalidated"
                continue
            }

            metadata["chunkTask-\(index)"] =
                "chunkNumber:\(object.chunkNumber) uploaded:\(String(describing: object.chunk)) error:\(String(describing: object.error))"
        }

        metadata["file.uploadingSession.isExpired"] = sessionTask.isExpired
        metadata["file.uploadingSession.sessionExpiration"] = sessionTask.sessionExpiration

        // Log uploadSession status
        guard let uploadSession = sessionTask.uploadSession else {
            metadata["file.uploadingSession.uploadSession"] = "nil"
            return metadata
        }

        guard !uploadSession.isInvalidated else {
            metadata["file.uploadingSession.uploadSession"] = "isInvalidated"
            return metadata
        }

        // Log uploadingSession.uploadSession state
        metadata["file.uploadingSession.uploadSession.result"] = uploadSession.result
        metadata["file.uploadingSession.uploadSession.token"] = uploadSession.token

        return metadata
    }
}

/// Provide a useable debug output of `ApiError`
extension ApiError: CustomDebugStringConvertible {
    public var debugDescription: String { "<ApiError: code:\(code) description:\(description)>" }
}
