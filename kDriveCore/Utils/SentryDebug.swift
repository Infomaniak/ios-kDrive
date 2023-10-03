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
import UIKit

/// Something to track errors
public enum SentryDebug {
    enum Category {
        static let uploadOperation = "UploadOperation"
        static let uploadQueue = "UploadQueue"
    }

    enum ErrorNames {
        static let uploadErrorHandling = "UploadErrorHandling"
        static let uploadErrorUserNotification = "UploadErrorUserNotification"
    }

    // MARK: - UploadOperation

    static func uploadOperationBeginBreadcrumb(_ uploadFileId: String) {
        let breadcrumb = Breadcrumb(level: .info, category: Category.uploadOperation)
        breadcrumb.message = "Begin for \(uploadFileId)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationEndBreadcrumb(_ uploadFileId: String, _ error: Error?) {
        let breadcrumb = Breadcrumb(level: (error == nil) ? .info : .error, category: Category.uploadOperation)
        breadcrumb.message = "End for \(uploadFileId)"
        if let error {
            breadcrumb.data = ["error": error]
        }
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationFinishedBreadcrumb(_ uploadFileId: String) {
        let breadcrumb = Breadcrumb(level: .info, category: Category.uploadOperation)
        breadcrumb.message = "Finished for \(uploadFileId)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationCloseSessionAndEndBreadcrumb(_ uploadFileId: String) {
        let breadcrumb = Breadcrumb(level: .info, category: Category.uploadOperation)
        breadcrumb.message = "Close session and end for \(uploadFileId)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationCleanSessionRemotelyBreadcrumb(_ uploadFileId: String, _ success: Bool) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = "Clean uploading session remotely for \(uploadFileId), success:\(success)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationCleanSessionBreadcrumb(_ uploadFileId: String) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = "Clean uploading session for \(uploadFileId)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationBackgroundExpiringBreadcrumb(_ uploadFileId: String) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = "Background task expiring for \(uploadFileId)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationRetryCountDecreaseBreadcrumb(_ uploadFileId: String, _ retryCount: Int) {
        let breadcrumb = Breadcrumb(level: .info, category: Category.uploadOperation)
        breadcrumb.message = "Background task for \(uploadFileId) try decrement retryCount:\(retryCount)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationErrorHandling(_ error: Error, _ metadata: [String: Any]) {
        // Add a breadcrumb for any error
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = ErrorNames.uploadErrorHandling
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)

        // Skip operationFinished
        // And we capture the upload error with a detailed state of the upload task.
        if let error = error as? UploadOperation.ErrorDomain,
           error == .operationFinished {
            return
        }

        SentrySDK.capture(message: ErrorNames.uploadErrorHandling) { scope in
            scope.setExtras(metadata)
        }
    }

    // MARK: - Upload notifications

    static func uploadNotificationError(_ metadata: [String: Any]) {
        SentrySDK.capture(message: ErrorNames.uploadErrorUserNotification) { scope in
            scope.setExtras(metadata)
        }
    }

    static func uploadNotificationBreadcrumb(_ metadata: [String: Any]) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = ErrorNames.uploadErrorUserNotification
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    // MARK: - UploadQueue

    static func uploadQueueBreadcrumb(caller: String = #function, isError: Bool = false, metadata: [String: Any]? = nil) {
        let breadcrumb = Breadcrumb(level: isError ? .error : .info, category: Category.uploadQueue)
        breadcrumb.message = caller
        if let metadata {
            breadcrumb.data = metadata
        }
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    // MARK: - Logger

    public static func loggerBreadcrumb(caller: String, category: String) {
        Task { @MainActor in
            let message = "\(caller) foreground:\(UIApplication.shared.applicationState != .background)"
            Task {
                let breadcrumb = Breadcrumb(level: .info, category: category)
                breadcrumb.message = message
                SentrySDK.addBreadcrumb(breadcrumb)
            }
        }
    }
}
