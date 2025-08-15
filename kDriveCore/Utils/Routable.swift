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
import UIKit

/// Abstract `Routes` that can be navigated to
public enum NavigationRoutes: Equatable {
    case store(driveId: Int, userId: Int)
    case saveFiles(files: [ImportedFile])
    case sharedWithMe(sharedWithMeLink: SharedWithMeLink)
    case trash(trashLink: TrashLink)
    case office(officeLink: OfficeLink)
    case privateShare(privateShareLink: PrivateShareLink)
    case directory(directoryLink: DirectoryLink)

    public static func == (lhs: NavigationRoutes, rhs: NavigationRoutes) -> Bool {
        switch (lhs, rhs) {
        case (.store(let lhdDriveId, let lhdUserId), .store(let rhdDriveId, let rhdUserId)):
            return lhdDriveId == rhdDriveId && lhdUserId == rhdUserId
        case (.saveFiles(let lhdFile), .saveFiles(let rhdDile)):
            return lhdFile == rhdDile
        case (.sharedWithMe(let lhdSharedWithMeLink), .sharedWithMe(let rhdSharedWithMeLink)):
            return lhdSharedWithMeLink == rhdSharedWithMeLink
        case(.trash(let lhdTrashLink), .trash(let rhdTrashLink)):
            return lhdTrashLink == rhdTrashLink
        case(.office(let lhdOfficeLink), .office(let rhdOfficeLink)):
            return lhdOfficeLink == rhdOfficeLink
        case(.privateShare(let lhdPrivateShareLink), .privateShare(let rhdprivateShareLink)):
            return lhdPrivateShareLink == rhdprivateShareLink
        case(.directory(let lhdDirectoryLink), .directory(let rhdDirectoryLink)):
            return lhdDirectoryLink == rhdDirectoryLink
        default:
            return false
        }
    }
}

/// Abstract app routing protocol
public protocol Routable {
    /// Navigate to a specified abstracted location
    @MainActor func navigate(to route: NavigationRoutes) async
}
