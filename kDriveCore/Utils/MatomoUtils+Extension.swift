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
import SwiftUICore

public extension MatomoUtils.View {
    static let shareAndRights = MatomoUtils.View(displayName: "ShareAndRights")
    static let save = MatomoUtils.View(displayName: "Save")
    static let search = MatomoUtils.View(displayName: "Search")
    static let uploadQueue = MatomoUtils.View(displayName: "UploadQueue")
    static let preview = MatomoUtils.View(displayName: "Preview")
    static let menu = MatomoUtils.View(displayName: "Menu")
    static let settings = MatomoUtils.View(displayName: "Settings")
    static let store = MatomoUtils.View(displayName: "Store")
    static let security = MatomoUtils.View(displayName: "Security")
}

public extension MatomoUtils.EventCategory {
    static let newElement = MatomoUtils.EventCategory(displayName: "newElement")
    static let fileListFileAction = MatomoUtils.EventCategory(displayName: "fileListFileAction")
    static let picturesFileAction = MatomoUtils.EventCategory(displayName: "picturesFileAction")
    static let fileInfo = MatomoUtils.EventCategory(displayName: "fileInfo")
    static let shareAndRights = MatomoUtils.EventCategory(displayName: "shareAndRights")
    static let colorFolder = MatomoUtils.EventCategory(displayName: "colorFolder")
    static let categories = MatomoUtils.EventCategory(displayName: "categories")
    static let search = MatomoUtils.EventCategory(displayName: "search")
    static let fileList = MatomoUtils.EventCategory(displayName: "fileList")
    static let comment = MatomoUtils.EventCategory(displayName: "comment")
    static let drive = MatomoUtils.EventCategory(displayName: "drive")
    static let settings = MatomoUtils.EventCategory(displayName: "settings")
    static let photoSync = MatomoUtils.EventCategory(displayName: "photoSync")
    static let home = MatomoUtils.EventCategory(displayName: "home")
    static let displayList = MatomoUtils.EventCategory(displayName: "displayList")
    static let inApp = MatomoUtils.EventCategory(displayName: "inApp")
    static let trash = MatomoUtils.EventCategory(displayName: "trash")
    static let dropbox = MatomoUtils.EventCategory(displayName: "dropbox")
    static let preview = MatomoUtils.EventCategory(displayName: "preview")
    static let mediaPlayer = MatomoUtils.EventCategory(displayName: "mediaPlayer")
    static let shortcuts = MatomoUtils.EventCategory(displayName: "shortcuts")
    static let deeplink = MatomoUtils.EventCategory(displayName: "deeplink")
    static let publicShareAction = MatomoUtils.EventCategory(displayName: "publicShareAction")
    static let publicSharePasswordAction = MatomoUtils.EventCategory(displayName: "publicSharePasswordAction")
    static let myKSuite = MatomoUtils.EventCategory(displayName: "myKSuite")
    static let myKSuiteUpgradeBottomSheet = MatomoUtils.EventCategory(displayName: "myKSuiteUpgradeBottomSheet")
}

public extension MatomoUtils {
    enum MediaPlayerType: String {
        case audio, video
    }

    // MARK: - DropBox

    func trackDropBoxSettings(_ settings: DropBoxSettings, passwordEnabled: Bool) {
        track(eventWithCategory: .dropbox, name: "switchEmailOnFileImport", value: settings.emailWhenFinished)
        track(eventWithCategory: .dropbox, name: "switchProtectWithPassword", value: passwordEnabled)
        track(eventWithCategory: .dropbox, name: "switchExpirationDate", value: settings.validUntil != nil)
        track(eventWithCategory: .dropbox, name: "switchLimitStorageSpace", value: settings.limitFileSize != nil)
        if let size = settings.limitFileSize {
            track(eventWithCategory: .dropbox, action: .input, name: "changeLimitStorage", value: Float(size.toGibibytes))
        }
    }

    // MARK: - Preview file

    func trackPreview(file: File) {
        track(eventWithCategory: .preview, name: "preview\(file.convertedType.rawValue.capitalized)")
    }

    // MARK: - Media player

    func trackMediaPlayer(playMedia: MatomoUtils.MediaPlayerType) {
        track(eventWithCategory: .mediaPlayer, name: "play\(playMedia.rawValue.capitalized)")
    }

    func trackMediaPlayer(leaveAt percentage: Double?) {
        track(eventWithCategory: .mediaPlayer, name: "duration", value: Float(percentage ?? 0))
    }
}
