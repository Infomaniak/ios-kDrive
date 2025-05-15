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
import InfomaniakCoreCommonUI
import kDriveCore

extension MatomoUtils {
    // MARK: - Share and Rights

    func trackRightSelection(type: RightsSelectionType, selected right: String) {
        switch type {
        case .shareLinkSettings:
            track(eventWithCategory: .shareAndRights, name: "\(right)ShareLink")
        case .addUserRights, .officeOnly:
            if right == UserPermission.delete.rawValue {
                track(eventWithCategory: .shareAndRights, name: "deleteUser")
            } else {
                track(eventWithCategory: .shareAndRights, name: "\(right)Right")
            }
        }
    }

    func trackShareLinkSettings(protectWithPassword: Bool, downloadFromLink: Bool, expirationDateLink: Bool) {
        track(eventWithCategory: .shareAndRights, name: "protectWithPassword", value: protectWithPassword)
        track(eventWithCategory: .shareAndRights, name: "downloadFromLink", value: downloadFromLink)
        track(eventWithCategory: .shareAndRights, name: "expirationDateLink", value: expirationDateLink)
    }

    // MARK: - File action

    #if !ISEXTENSION

    func trackBuklAction(action: FloatingPanelAction, files: [File], category: EventCategory) {
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
