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

extension PhotoSyncSettingsViewController {
    func trackPhotoSync(isEnabled: Bool, with settings: PhotoSyncSettings) {
        @InjectService var matomo: MatomoUtils
        matomo.track(eventWithCategory: .photoSync, name: isEnabled ? "enabled" : "disabled")
        if isEnabled {
            matomo.track(
                eventWithCategory: .photoSync,
                name: "sync\(["New", "All", "FromDate"][settings.syncMode.rawValue])"
            )
            matomo.track(eventWithCategory: .photoSync, name: "importDCIM", value: settings.syncPicturesEnabled)
            matomo.track(eventWithCategory: .photoSync, name: "importVideos", value: settings.syncVideosEnabled)
            matomo.track(eventWithCategory: .photoSync, name: "importScreenshots", value: settings.syncScreenshotsEnabled)
            matomo.track(eventWithCategory: .photoSync, name: "createDatedFolders", value: settings.createDatedSubFolders)
            matomo.track(eventWithCategory: .photoSync, name: "deleteAfterImport", value: settings.deleteAssetsAfterImport)
            matomo.track(eventWithCategory: .photoSync, name: "importPhotosIn\(settings.photoFormat.title)")
        }
    }
}
