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

/// Something to generate a File Name, testable
struct PHAssetNameProvider {
    /// The date formatter specific to kDrive and file name format
    static let fileNameDateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSSS"
        return dateFormatter
    }()

    static let noName = "No-name"

    /// Default file name
    func defaultFileName(_ burstString: String, _ fileExtension: String, _ now: Date) -> String {
        "\(Self.noName)-\(URL.defaultFileName(date: now))\(burstString).\(fileExtension)"
    }

    func isPictureWithChanges(originalFilename: String) -> Bool {
        // Require a valid originalFilename
        guard !originalFilename.isEmpty else {
            return false
        }

        let lastPathComponent = originalFilename.split(separator: ".")
        let filename = lastPathComponent[0]

        // Edited pictures will have a "FullSizeRender" name
        guard filename == "FullSizeRender" else {
            return false
        }

        return true
    }

    /// Get a filename that can be used by kDrive, taking into consideration burst and edits of a PHAsset.
    func getFilename(fileExtension: String,
                     originalFilename: String?,
                     creationDate: Date?,
                     modificationDate: Date?,
                     burstCount: Int?,
                     burstIdentifier: String?,
                     now: Date = Date()) -> String {
        let fileExtension = fileExtension.lowercased()
        let burstString: String
        if let burstCount,
           burstCount > 0,
           let burstIdentifier,
           !burstIdentifier.isEmpty {
            burstString = "_\(burstCount)"
        } else {
            burstString = ""
        }

        // Require a valid originalFilename
        guard let originalFilename, !originalFilename.isEmpty else {
            return defaultFileName(burstString, fileExtension, now)
        }

        // Edited pictures need some extra work
        if isPictureWithChanges(originalFilename: originalFilename) {
            // Differentiate the file with edit date
            let editDate = modificationDate ?? now
            if modificationDate == nil {
                let message = "We are trying to generate a file name for a modified file, without a modification date"
                let metadata = ["function": #function]
                SentryDebug.addBreadcrumb(message: message, category: .viewModel, level: .error, metadata: metadata)
                SentryDebug.capture(message: SentryDebug.ErrorNames.viewModelNotConnectedToView, extras: metadata)
            }

            // Making sure edited pictures on Photo.app have a unique name that will trigger an upload and do not collide.
            guard let creationDate else {
                return "\(Self.noName)-\(Self.fileNameDateFormatter.string(from: editDate))\(burstString).\(fileExtension)"
            }
            return "\(Self.fileNameDateFormatter.string(from: creationDate))-\(Self.fileNameDateFormatter.string(from: editDate))\(burstString).\(fileExtension)"
        }

        // Standard kDrive date formating
        guard let creationDate else {
            return defaultFileName(burstString, fileExtension, now)
        }

        return "\(Self.fileNameDateFormatter.string(from: creationDate))\(burstString).\(fileExtension)"
    }
}
