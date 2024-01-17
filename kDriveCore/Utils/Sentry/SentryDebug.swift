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
    public enum Category: String {
        /// Upload operation error handling
        case uploadOperation = "UploadOperation"
        /// Upload queue error handling
        case uploadQueue = "UploadQueue"
        /// API errors, not token related
        case apiError = "APIError"
        /// API token
        case apiToken = "Token"
        /// View model update
        case viewModel = "ViewModel"
        /// Model migration
        case realmMigration = "RealmMigration"
        /// Photo library assets
        case PHAsset
    }

    public enum EventNames {
        static let uploadCompletedSuccess = "UploadCompletedSuccess"
    }

    public enum ErrorNames {
        static let uploadErrorHandling = "UploadErrorHandling"
        static let uploadSessionErrorHandling = "UploadSessionErrorHandling"
        static let uploadErrorUserNotification = "UploadErrorUserNotification"
        static let viewModelNotConnectedToView = "ViewModelNotConnected"
    }

    // MARK: - View Model Observation

    public static func viewModelObservationError(_ function: String = #function) {
        let metadata = ["function": function]
        let message = "The ViewModel is not linked to a view to dispatch changes"

        addBreadcrumb(message: message, category: .viewModel, level: .error, metadata: metadata)
        capture(message: ErrorNames.viewModelNotConnectedToView, extras: metadata)
    }

    // MARK: - Logger

    public static func loggerBreadcrumb(caller: String, metadata: [String: Any]? = nil, isError: Bool = false) {
        Task {
            let isForeground = await UIApplication.shared.applicationState != .background
            let message = "\(caller) foreground:\(isForeground)"

            addBreadcrumb(message: message, category: .uploadOperation, level: isError ? .error : .info, metadata: metadata)
        }
    }

    // MARK: - No Window

    public static func captureNoWindow() {
        capture(message: "Trying to call show with no window")
    }

    // MARK: - SHARED -

    public static func addBreadcrumb(
        message: String,
        category: SentryDebug.Category,
        level: SentryLevel,
        metadata: [String: Any]? = nil
    ) {
        Task {
            let breadcrumb = Breadcrumb(level: level, category: category.rawValue)
            breadcrumb.message = message
            breadcrumb.data = metadata
            SentrySDK.addBreadcrumb(breadcrumb)
        }
    }

    public static func capture(
        error: Error,
        context: [String: Any]? = nil,
        contextKey: String? = nil,
        extras: [String: Any]? = nil
    ) {
        Task {
            SentrySDK.capture(error: error) { scope in
                if let context, let contextKey {
                    scope.setContext(value: context, key: contextKey)
                }

                if let extras {
                    scope.setExtras(extras)
                }
            }
        }
    }

    public static func capture(
        message: String,
        context: [String: Any]? = nil,
        contextKey: String? = nil,
        extras: [String: Any]? = nil
    ) {
        Task {
            SentrySDK.capture(message: message) { scope in
                if let context, let contextKey {
                    scope.setContext(value: context, key: contextKey)
                }

                if let extras {
                    scope.setExtras(extras)
                }
            }
        }
    }
}
