/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import kDriveCore
import Sentry

/// Records breadcrumbs immediately, before preview operations that may crash.
enum PreviewBreadcrumb {
    struct CellContext {
        let sessionId: String
        let item: Int
    }

    enum ReloadReason: String {
        case fileUpdated
        case networkChanged
        case downloadCompleted
        case downloadFailed
        case officePreviewProgress
        case officePreviewCompleted
    }

    static func record(_ message: String, metadata: [String: Any]) {
        let breadcrumb = Breadcrumb(level: .info, category: "FilePreview")
        breadcrumb.message = message
        for (key, value) in metadata {
            breadcrumb.setData(value: value, key: key)
        }
        SentrySDK.addBreadcrumb(breadcrumb)
    }

    static func record(_ message: String, error: DriveError?, metadata: [String: Any]) {
        var metadata = metadata
        switch error {
        case nil:
            metadata["outcome"] = "success"
        case .taskCancelled?:
            metadata["outcome"] = "cancelled"
        default:
            metadata["outcome"] = "failed"
        }
        record(message, metadata: metadata)
    }
}
