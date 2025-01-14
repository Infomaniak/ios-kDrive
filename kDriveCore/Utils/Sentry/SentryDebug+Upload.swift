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

extension SentryDebug {
    // MARK: - UploadOperation

    static func uploadOperationBeginBreadcrumb(_ uploadFileId: String) {
        addBreadcrumb(message: "Begin for \(uploadFileId)", category: .uploadOperation, level: .info)
    }

    static func uploadOperationEndBreadcrumb(_ uploadFileId: String, _ error: Error?) {
        addBreadcrumb(
            message: "End for \(uploadFileId)",
            category: .uploadOperation,
            level: (error == nil) ? .info : .error,
            metadata: ["error": error ?? "nil"]
        )
    }

    static func uploadOperationFinishedBreadcrumb(_ uploadFileId: String) {
        addBreadcrumb(message: "Finished for \(uploadFileId)", category: .uploadOperation, level: .info)
    }

    static func uploadOperationCloseSessionAndEndBreadcrumb(_ uploadFileId: String) {
        let message = "Close session and end for \(uploadFileId)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .info)
    }

    static func uploadOperationCleanSessionRemotelyBreadcrumb(_ uploadFileId: String, _ success: Bool) {
        let message = "Clean uploading session remotely for \(uploadFileId), success:\(success)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error)
    }

    static func uploadOperationCleanSessionBreadcrumb(_ uploadFileId: String) {
        let message = "Clean uploading session for \(uploadFileId)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error)
    }

    static func uploadOperationBackgroundExpiringBreadcrumb(_ uploadFileId: String) {
        let message = "Background task expiring for \(uploadFileId)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error)
    }

    static func uploadOperationRetryCountDecreaseBreadcrumb(_ uploadFileId: String, _ retryCount: Int) {
        let message = "Try decrement retryCount:\(retryCount) for \(uploadFileId)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .info)
    }

    static func uploadOperationRescheduledBreadcrumb(_ uploadFileId: String, _ metadata: [String: Any]) {
        let message = "UploadOperation for \(uploadFileId) rescheduled"
        addBreadcrumb(message: message, category: .uploadOperation, level: .info)
    }

    static func uploadOperationErrorHandling(_ message: String, _ error: Error, _ metadata: [String: Any]) {
        // Add a breadcrumb for any error
        SentryDebug.addBreadcrumb(message: message, category: .uploadOperation, level: .error, metadata: metadata)

        // Skip operationFinished
        // And we capture the upload error with a detailed state of the upload task.
        if let error = error as? UploadOperation.ErrorDomain,
           error == .operationFinished {
            return
        }

        SentryDebug.capture(message: ErrorNames.uploadErrorHandling, extras: metadata)
    }

    static func uploadOperationChunkInFailureCannotCloseSessionBreadcrumb(_ uploadFileId: String, _ metadata: [String: Any]) {
        let message = "Cannot close session for \(uploadFileId)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error, metadata: metadata)
    }

    public static func updateFileListBreadcrumb(id: String, step: String) {
        let message = "updateFileList opId: \(id) step: \(step)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error)
    }

    public static func setFileListViewModelBreadcrumb(id: String, step: String) {
        let message = "setFileList opId: \(id) step: \(step)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error)
    }

    public static func filesObservationBreadcrumb(state: String) {
        let message = "files modified: \(state)"
        addBreadcrumb(message: message, category: .uploadOperation, level: .error)
    }

    static func uploadOperationCompletedWithSuccess(_ metadata: [String: Any] = [:]) {
        SentryDebug.capture(message: EventNames.uploadCompletedSuccess, extras: metadata)
    }

    static func capturePHAssetResourceManagerError(
        _ error: Error,
        requestId: Int32 = Int32(NSNotFound),
        function: StaticString = #function
    ) {
        let context: [String: AnyHashable] = [
            "requestId": requestId,
            "func": "\(function)",
            "error": "\(error)",
            "localizedError": error.localizedDescription
        ]
        SentryDebug.capture(message: ErrorNames.assetResourceManagerError, context: context, level: .error)
    }

    // MARK: - Upload notifications

    static func uploadNotificationError(_ metadata: [String: Any]) {
        capture(message: ErrorNames.uploadErrorUserNotification, extras: metadata)
    }

    static func uploadNotificationBreadcrumb(_ metadata: [String: Any]) {
        addBreadcrumb(
            message: ErrorNames.uploadErrorUserNotification,
            category: .uploadOperation,
            level: .error,
            metadata: metadata
        )
    }
}
