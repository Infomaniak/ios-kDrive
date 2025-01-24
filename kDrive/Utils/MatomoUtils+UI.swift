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
import kDriveCore

extension MatomoUtils {
    // MARK: - Share and Rights

    static func trackRightSelection(type: RightsSelectionType, selected right: String) {
        switch type {
        case .shareLinkSettings:
            MatomoUtils.track(eventWithCategory: .shareAndRights, name: "\(right)ShareLink")
        case .addUserRights, .officeOnly:
            if right == UserPermission.delete.rawValue {
                MatomoUtils.track(eventWithCategory: .shareAndRights, name: "deleteUser")
            } else {
                MatomoUtils.track(eventWithCategory: .shareAndRights, name: "\(right)Right")
            }
        }
    }

    static func trackShareLinkSettings(protectWithPassword: Bool, downloadFromLink: Bool, expirationDateLink: Bool) {
        MatomoUtils.track(eventWithCategory: .shareAndRights, name: "protectWithPassword", value: protectWithPassword)
        MatomoUtils.track(eventWithCategory: .shareAndRights, name: "downloadFromLink", value: downloadFromLink)
        MatomoUtils.track(eventWithCategory: .shareAndRights, name: "expirationDateLink", value: expirationDateLink)
    }

    // MARK: - File action

    #if !ISEXTENSION

    static func trackFileAction(action: FloatingPanelAction, file: File, category: EventCategory) {
        switch action {
        // Quick Actions
        case .sendCopy:
            track(eventWithCategory: category, name: "sendFileCopy")
        case .shareLink:
            track(eventWithCategory: category, name: "shareLink")
        case .informations:
            track(eventWithCategory: category, name: "openFileInfos")
        // Actions
        case .duplicate:
            track(eventWithCategory: category, name: "copy")
        case .move:
            track(eventWithCategory: category, name: "move")
        case .download:
            track(eventWithCategory: category, name: "download")
        case .favorite:
            track(eventWithCategory: category, name: "favorite", value: !file.isFavorite)
        case .offline:
            track(eventWithCategory: category, name: "offline", value: !file.isAvailableOffline)
        case .rename:
            track(eventWithCategory: category, name: "rename")
        case .delete:
            track(eventWithCategory: category, name: "putInTrash")
        case .convertToDropbox:
            track(eventWithCategory: category, name: "convertToDropBox")
        default:
            break
        }
    }

    static func trackBuklAction(action: FloatingPanelAction, files: [File], category: EventCategory) {
        let numberOfFiles = files.count
        switch action {
        // Quick Actions
        case .duplicate:
            trackBulkEvent(eventWithCategory: category, name: "Copy", numberOfItems: numberOfFiles)
        case .download:
            trackBulkEvent(eventWithCategory: category, name: "Download", numberOfItems: numberOfFiles)
        case .favorite:
            trackBulkEvent(eventWithCategory: category, name: "Add_favorite", numberOfItems: numberOfFiles)
        case .offline:
            trackBulkEvent(eventWithCategory: category, name: "Set_offline", numberOfItems: numberOfFiles)
        case .delete:
            trackBulkEvent(eventWithCategory: category, name: "Trash", numberOfItems: numberOfFiles)
        case .folderColor:
            trackBulkEvent(eventWithCategory: category, name: "Color_folder", numberOfItems: numberOfFiles)
        default:
            break
        }
    }

    #endif
}
