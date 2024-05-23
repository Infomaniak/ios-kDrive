/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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

import CocoaLumberjackSwift
import Foundation
import InfomaniakDI
import kDriveCore
import kDriveResources
import SwiftRegex
import UIKit

#if !ISEXTENSION
enum UniversalLinksHelper {
    private struct Link {
        let regex: Regex
        let displayMode: DisplayMode

        /// Matches a private share link
        static let privateShareLink = Link(
            regex: Regex(pattern: #"^/app/drive/([0-9]+)/redirect/([0-9]+)$"#)!,
            displayMode: .file
        )
        /// Matches a directory list link
        static let directoryLink = Link(regex: Regex(pattern: #"^/app/drive/([0-9]+)/files/([0-9]+)$"#)!, displayMode: .file)
        /// Matches a file preview link
        static let filePreview = Link(
            regex: Regex(pattern: #"^/app/drive/([0-9]+)/files/([0-9]+/)?preview/[a-z]+/([0-9]+)$"#)!,
            displayMode: .file
        )
        /// Matches an office file link
        static let officeLink = Link(regex: Regex(pattern: #"^/app/office/([0-9]+)/([0-9]+)$"#)!, displayMode: .office)

        static let all = [privateShareLink, directoryLink, filePreview, officeLink]
    }

    private enum DisplayMode {
        case office, file
    }

    static func handlePath(_ path: String, appDelegate: AppDelegate) -> Bool {
        DDLogInfo("[UniversalLinksHelper] Trying to open link with path: \(path)")

        for link in Link.all {
            let matches = link.regex.matches(in: path)
            if processRegex(matches: matches, displayMode: link.displayMode, appDelegate: appDelegate) {
                return true
            }
        }

        DDLogWarn("[UniversalLinksHelper] Unable to process link with path: \(path)")
        return false
    }

    private static func processRegex(matches: [[String]], displayMode: DisplayMode, appDelegate: AppDelegate) -> Bool {
        @InjectService var accountManager: AccountManageable

        guard let firstMatch = matches.first,
              firstMatch.count > 2,
              let driveId = Int(firstMatch[1]),
              let last = firstMatch.last,
              let uploadFileId = Int(last),
              let driveFileManager = accountManager.getDriveFileManager(for: driveId,
                                                                        userId: accountManager.currentUserId)
        else { return false }

        openFile(id: uploadFileId, driveFileManager: driveFileManager, office: displayMode == .office, appDelegate: appDelegate)

        return true
    }

    private static func openFile(id: Int, driveFileManager: DriveFileManager, office: Bool, appDelegate: AppDelegate) {
        Task {
            do {
                let file = try await driveFileManager.file(id: id)
                @InjectService var appNavigable: AppNavigable
                await appNavigable.present(file: file, driveFileManager: driveFileManager, office: office)
            } catch {
                DDLogError("[UniversalLinksHelper] Failed to get file [\(driveFileManager.drive.id) - \(id)]: \(error)")
                await UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
    }
}
#endif
