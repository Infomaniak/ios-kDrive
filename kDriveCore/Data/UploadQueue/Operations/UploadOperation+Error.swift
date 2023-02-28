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
        }
        catch {
            defer {
                end()
            }
            
            UploadOperationLog("catching error:\(error) fid:\(fileId)", level: .error)
            if !handleLocalErrors(error: error) {
                handleRemoteErrors(error: error)
            }
            
            return
        }
    }
    
    // MARK: - Local Errors
    
    @discardableResult
    func handleLocalErrors(error: Error) -> Bool {
        var errorHandled: Bool = false
        try? transactionWithFile { file in
            // Not enough space
            if case .notEnoughSpace = error as? FreeSpaceService.StorageIssues {
                self.uploadNotifiable.sendNotEnoughSpaceForUpload(filename: file.name)
                file.maxRetryCount = 0
                file.progress = nil
                file.error = DriveError.errorDeviceStorage.wrapping(error)
                errorHandled = true
            }
            
            // Local file has been removed, delete the operation
            else if let error = error as? DriveError,
               error == .fileNotFound {
                file.maxRetryCount = 0
                file.progress = nil
                file.error = DriveError.taskCancelled // cascade deletion
                errorHandled = true
            }
            
            // specialized local errors
            else if let error = error as? UploadOperation.ErrorDomain {
                switch error {
                case .unableToBuildRequest:
                    file.error = DriveError.localError.wrapping(error)
                    
                case .uploadSessionTaskMissing, .uploadSessionInvalid:
                    self.cleanUploadFileSession(file: file)
                    file.error = DriveError.localError.wrapping(error)

                case .unableToMatchUploadChunk, .splitError, .chunkError, .fileIdentityHasChanged, .parseError, .missingChunkHash:
                    self.cleanUploadFileSession(file: file)
                    file.error = DriveError.localError.wrapping(error)
                    
                case .operationFinished, .operationCanceled:
                    UploadOperationLog("catching operation is terminating")
                    // the operation is terminating, silent handling
                    break
                    
                case .databaseUploadFileNotFound:
                    // Silently stop if an UploadFile is no longer in base
                    self.cancel()
                }
                
                errorHandled = true
            }
            
            else {
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
            return false
        }
        
        var cleanLinkedFiles: (parentDirectoryId: Int, userId: Int, driveId: Int)?
        var errorHandled: Bool = false
        try? transactionWithFile { file in
            defer {
                UploadOperationLog("catching remote error:\(error) fid:\(self.fileId)", level: .error)
                file.error = error
            }
            
            switch error {
            case .fileAlreadyExistsError:
                file.maxRetryCount = 0
                file.progress = nil
                
            case .lock:
                // simple retry
                break
            case .notAuthorized, .maintenance:
                // simple retry
                break
                
            case .quotaExceeded:
                file.maxRetryCount = 0
                file.progress = nil
        
            case .uploadNotTerminatedError, .uploadNotTerminated:
                self.cleanUploadFileSession(file: file)
                
            case .invalidUploadTokenError, .uploadError, .uploadFailedError, .uploadTokenIsNotValid:
                self.cleanUploadFileSession(file: file)
            
            case .objectNotFound, .uploadDestinationNotFoundError, .uploadDestinationNotWritableError:
                // If we get an ”object not found“ error, we cancel all further uploads in this folder
                file.maxRetryCount = 0
                file.progress = nil
                self.cleanUploadFileSession(file: file)
                cleanLinkedFiles = (file.parentDirectoryId, file.userId, file.driveId)
                
            default:
                // simple retry
                break
            }
            
            errorHandled = true
        }
        
        if let cleanLinkedFiles {
            // Chain database queries outside of transactionWithFile
            self.uploadQueue.cancelAllOperations(withParent: cleanLinkedFiles.parentDirectoryId,
                                                 userId: cleanLinkedFiles.userId,
                                                 driveId: cleanLinkedFiles.driveId)
                
            if self.photoLibraryUploader.isSyncEnabled
                && self.photoLibraryUploader.settings?.parentDirectoryId == cleanLinkedFiles.parentDirectoryId {
                self.photoLibraryUploader.disableSync()
                NotificationsHelper.sendPhotoSyncErrorNotification()
            }
        }
        
        return errorHandled
    }
}
