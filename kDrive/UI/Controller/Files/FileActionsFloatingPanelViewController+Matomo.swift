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

extension FileActionsFloatingPanelViewController {
    #if !ISEXTENSION

    func trackFileAction(action: FloatingPanelAction, file: File, category: MatomoUtils.EventCategory) {
        @InjectService var matomo: MatomoUtils
        switch action {
        // Quick Actions
        case .sendCopy:
            matomo.track(eventWithCategory: category, name: "sendFileCopy")
        case .shareLink:
            matomo.track(eventWithCategory: category, name: "shareLink")
        case .informations:
            matomo.track(eventWithCategory: category, name: "openFileInfos")
        // Actions
        case .duplicate:
            matomo.track(eventWithCategory: category, name: "copy")
        case .move:
            matomo.track(eventWithCategory: category, name: "move")
        case .download:
            matomo.track(eventWithCategory: category, name: "download")
        case .favorite:
            matomo.track(eventWithCategory: category, name: "favorite", value: !file.isFavorite)
        case .offline:
            matomo.track(eventWithCategory: category, name: "offline", value: !file.isAvailableOffline)
        case .rename:
            matomo.track(eventWithCategory: category, name: "rename")
        case .delete:
            matomo.track(eventWithCategory: category, name: "putInTrash")
        case .convertToDropbox:
            matomo.track(eventWithCategory: category, name: "convertToDropBox")
        default:
            break
        }
    }
    #endif
}
