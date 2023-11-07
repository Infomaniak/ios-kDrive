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
        static let apiError = "APIError"
        static let viewModel = "ViewModel"
        static let realmMigration = "RealmMigration"
    }

    enum ErrorNames {
        static let uploadErrorHandling = "UploadErrorHandling"
        static let uploadSessionErrorHandling = "UploadSessionErrorHandling"
        static let uploadErrorUserNotification = "UploadErrorUserNotification"
        static let viewModelNotConnectedToView = "ViewModelNotConnected"
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
        breadcrumb.message = "Try decrement retryCount:\(retryCount) for \(uploadFileId)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationRescheduledBreadcrumb(_ uploadFileId: String, _ metadata: [String: Any]) {
        let breadcrumb = Breadcrumb(level: .info, category: Category.uploadOperation)
        breadcrumb.message = "UploadOperation for \(uploadFileId) rescheduled"
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func uploadOperationErrorHandling(_ message: String, _ error: Error, _ metadata: [String: Any]) {
        // Add a breadcrumb for any error
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = message
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

    static func uploadOperationChunkInFailureCannotCloseSessionBreadcrumb(_ uploadFileId: String, _ metadata: [String: Any]) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = "Cannot close session for \(uploadFileId)"
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    public static func updateFileListBreadcrumb(id: String, step: String) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = "updateFileList opId: \(id) step: \(step)"
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    public static func filesObservationBreadcrumb(state: String) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.uploadOperation)
        breadcrumb.message = "files modified: \(state) "
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    // MARK: - REALM Migration

    static func realmMigrationStartedBreadcrumb(form: UInt64, to: UInt64, realmName: String, function: String = #function) {
        realmMigrationBreadcrumb(state: .start, form: form, to: to, realmName: realmName, function: function)
    }

    static func realmMigrationEndedBreadcrumb(form: UInt64, to: UInt64, realmName: String, function: String = #function) {
        realmMigrationBreadcrumb(state: .end, form: form, to: to, realmName: realmName, function: function)
    }

    enum MigrationState: String {
        case start
        case end
    }

    private static func realmMigrationBreadcrumb(
        state: MigrationState,
        form: UInt64,
        to: UInt64,
        realmName: String,
        function: String
    ) {
        let metadata: [String: Any] = ["sate": state.rawValue,
                                       "realmName": realmName,
                                       "form": form,
                                       "to": to,
                                       "function": function]
        let breadcrumb = Breadcrumb(level: .info, category: Category.realmMigration)
        breadcrumb.message = Category.realmMigration
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)
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

    // MARK: - Error

    static func apiErrorBreadcrumb(_ message: String, _ metadata: [String: Any]) {
        let breadcrumb = Breadcrumb(level: .error, category: Category.apiError)
        breadcrumb.message = message
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    // MARK: - View Model Observation

    public static func viewModelObservationError(_ function: String = #function) {
        let metadata = ["function": function]

        let breadcrumb = Breadcrumb(level: .error, category: Category.viewModel)
        breadcrumb.message = "The ViewModel is not linked to a view to dispatch changes"
        breadcrumb.data = metadata
        SentrySDK.addBreadcrumb(breadcrumb)

        SentrySDK.capture(message: ErrorNames.viewModelNotConnectedToView) { scope in
            scope.setExtras(metadata)
        }
    }

    // MARK: - Logger

    public static func loggerBreadcrumb(caller: String, category: String, metadata: [String: Any]? = nil, isError: Bool = false) {
        Task { @MainActor in
            let isForeground = UIApplication.shared.applicationState != .background
            Task.detached {
                let message = "\(caller) foreground:\(isForeground)"
                let breadcrumb = Breadcrumb(level: isError ? .error : .info, category: category)
                breadcrumb.message = message
                breadcrumb.data = metadata
                SentrySDK.addBreadcrumb(breadcrumb)
            }
        }
    }
}
