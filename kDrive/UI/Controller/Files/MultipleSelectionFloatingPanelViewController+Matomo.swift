/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore

extension MultipleSelectionFloatingPanelViewController {
    #if !ISEXTENSION

    func trackBuklAction(action: FloatingPanelAction, files: [File], category: MatomoUtils.EventCategory) {
        @InjectService var matomo: MatomoUtils
        let numberOfFiles = files.count
        switch action {
        // Quick Actions
        case .duplicate:
            matomo.trackBulkEvent(eventWithCategory: category, name: "Copy", numberOfItems: numberOfFiles)
        case .download:
            matomo.trackBulkEvent(eventWithCategory: category, name: "Download", numberOfItems: numberOfFiles)
        case .favorite:
            matomo.trackBulkEvent(eventWithCategory: category, name: "Add_favorite", numberOfItems: numberOfFiles)
        case .offline:
            matomo.trackBulkEvent(eventWithCategory: category, name: "Set_offline", numberOfItems: numberOfFiles)
        case .delete:
            matomo.trackBulkEvent(eventWithCategory: category, name: "Trash", numberOfItems: numberOfFiles)
        case .folderColor:
            matomo.trackBulkEvent(eventWithCategory: category, name: "Color_folder", numberOfItems: numberOfFiles)
        default:
            break
        }
    }

    #endif
}
