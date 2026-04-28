/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

public extension SentryDebug {
    enum AvailableOfflineReason: String {
        case uploadCompletionOverwrite = "upload_completion_overwrite"
        case serverActivityRemoval = "server_activity_removal"
        case keepCacheAttributesMissingSavedFile = "keep_cache_attributes_missing_saved_file"
        case fileRemovedFromDatabase = "file_removed_from_database"
    }

    static func availableOfflineLost(
        fileId: Int,
        fileUid: String,
        reason: AvailableOfflineReason,
        additionalContext: [String: Any] = [:]
    ) {
        var metadata: [String: Any] = [
            "fileId": fileId,
            "fileUid": fileUid,
            "reason": reason.rawValue
        ]

        metadata.merge(additionalContext) { _, new in new }

        addBreadcrumb(
            message: "Available offline lost: \(reason.rawValue)",
            category: .availableOffline,
            level: .warning,
            metadata: metadata
        )

        capture(
            message: "AvailableOfflineLost",
            level: .warning,
            extras: metadata
        )
    }

    static func uploadCompletionOfflineCheck(
        fileId: Int,
        fileUid: String,
        existingFileWasOffline: Bool,
        newFileIsOffline: Bool
    ) {
        // Only log if we're about to lose offline status
        guard existingFileWasOffline, !newFileIsOffline else { return }

        availableOfflineLost(
            fileId: fileId,
            fileUid: fileUid,
            reason: .uploadCompletionOverwrite,
            additionalContext: [
                "existingFileWasOffline": existingFileWasOffline,
                "newFileIsOffline": newFileIsOffline
            ]
        )
    }

    static func keepCacheAttributesMissingSavedFile(
        fileId: Int,
        fileUid: String
    ) {
        let metadata: [String: Any] = [
            "fileId": fileId,
            "fileUid": fileUid,
            "reason": AvailableOfflineReason.keepCacheAttributesMissingSavedFile.rawValue
        ]

        let message = "keepCacheAttributesForFile: saved file not found for uid \(fileUid)"
        addBreadcrumb(
            message: message,
            category: .availableOffline,
            level: .info,
            metadata: metadata
        )

        capture(
            message: message,
            level: .warning,
            extras: metadata
        )
    }

    static func offlineFileRemovedFromDatabase(
        fileId: Int,
        fileUid: String,
        cascade: Bool
    ) {
        availableOfflineLost(
            fileId: fileId,
            fileUid: fileUid,
            reason: .fileRemovedFromDatabase,
            additionalContext: ["cascade": cascade]
        )
    }

    static func offlineFileRemovedByServerActivity(
        fileId: Int,
        fileUid: String,
        activityType: String
    ) {
        availableOfflineLost(
            fileId: fileId,
            fileUid: fileUid,
            reason: .serverActivityRemoval,
            additionalContext: ["activityType": activityType]
        )
    }
}
