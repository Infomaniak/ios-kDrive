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

import Foundation
import InfomaniakDI
import InfomaniakPrivacyManagement
import MatomoTracker

extension MatomoTracker: @retroactive MatomoOptOutable {
    public func optOut(_ setOptOut: Bool) {
        isOptedOut = setOptOut
    }
}

public enum MatomoUtils {
    public static let shared: MatomoTracker = {
        let tracker = MatomoTracker(siteId: "8", baseURL: URLConstants.matomo.url)

        #if DEBUG
        tracker.isOptedOut = true
        #endif

        @InjectService var accountManager: AccountManageable
        tracker.userId = String(accountManager.currentUserId)
        return tracker
    }()

    public enum Views: String {
        case shareAndRights, save, search, uploadQueue, preview, menu, settings, store, security

        public var displayName: String {
            return rawValue.capitalized
        }
    }

    public enum EventCategory: String {
        case newElement, fileListFileAction, picturesFileAction, fileInfo, shareAndRights, colorFolder, categories, search,
             fileList, comment, drive, account, settings, photoSync, home, displayList, inApp, trash,
             dropbox, preview, mediaPlayer, shortcuts, appReview, deeplink, publicShareAction, publicSharePasswordAction,
             myKSuite, myKSuiteUpgradeBottomSheet
    }

    public enum UserAction: String {
        case click, input
    }

    public enum MediaPlayerType: String {
        case audio, video
    }

    public static func connectUser() {
        @InjectService var accountManager: AccountManageable
        shared.userId = String(accountManager.currentUserId)
    }

    public static func track(view: [String]) {
        shared.track(view: view)
    }

    public static func track(
        eventWithCategory category: EventCategory,
        action: UserAction = .click,
        name: String,
        value: Float? = nil
    ) {
        shared.track(eventWithCategory: category.rawValue, action: action.rawValue, name: name, value: value)
    }

    public static func track(eventWithCategory category: EventCategory, action: UserAction = .click, name: String, value: Bool) {
        track(eventWithCategory: category, action: action, name: name, value: value ? 1.0 : 0.0)
    }

    public static func trackBulkEvent(eventWithCategory category: EventCategory, name: String, numberOfItems number: Int) {
        track(eventWithCategory: category, action: .click,
              name: "bulk\(number == 1 ? "Single" : "")\(name)", value: Float(number))
    }

    // MARK: - DropBox

    public static func trackDropBoxSettings(_ settings: DropBoxSettings, passwordEnabled: Bool) {
        track(eventWithCategory: .dropbox, name: "switchEmailOnFileImport", value: settings.emailWhenFinished)
        track(eventWithCategory: .dropbox, name: "switchProtectWithPassword", value: passwordEnabled)
        track(eventWithCategory: .dropbox, name: "switchExpirationDate", value: settings.validUntil != nil)
        track(eventWithCategory: .dropbox, name: "switchLimitStorageSpace", value: settings.limitFileSize != nil)
        if let size = settings.limitFileSize {
            track(eventWithCategory: .dropbox, action: .input, name: "changeLimitStorage", value: Float(size.toGibibytes))
        }
    }

    // MARK: - Photo Sync

    public static func trackPhotoSync(isEnabled: Bool, with settings: PhotoSyncSettings) {
        track(eventWithCategory: .photoSync, name: isEnabled ? "enabled" : "disabled")
        if isEnabled {
            MatomoUtils.track(
                eventWithCategory: .photoSync,
                name: "sync\(["New", "All", "FromDate"][settings.syncMode.rawValue])"
            )
            MatomoUtils.track(eventWithCategory: .photoSync, name: "importDCIM", value: settings.syncPicturesEnabled)
            MatomoUtils.track(eventWithCategory: .photoSync, name: "importVideos", value: settings.syncVideosEnabled)
            MatomoUtils.track(eventWithCategory: .photoSync, name: "importScreenshots", value: settings.syncScreenshotsEnabled)
            MatomoUtils.track(eventWithCategory: .photoSync, name: "createDatedFolders", value: settings.createDatedSubFolders)
            MatomoUtils.track(eventWithCategory: .photoSync, name: "deleteAfterImport", value: settings.deleteAssetsAfterImport)
            MatomoUtils.track(eventWithCategory: .photoSync, name: "importPhotosIn\(settings.photoFormat.title)")
        }
    }

    // MARK: - Preview file

    public static func trackPreview(file: File) {
        MatomoUtils.track(eventWithCategory: .preview, name: "preview\(file.convertedType.rawValue.capitalized)")
    }

    // MARK: - Media player

    public static func trackMediaPlayer(playMedia: MatomoUtils.MediaPlayerType) {
        track(eventWithCategory: .mediaPlayer, name: "play\(playMedia.rawValue.capitalized)")
    }

    public static func trackMediaPlayer(leaveAt percentage: Double?) {
        track(eventWithCategory: .mediaPlayer, name: "duration", value: Float(percentage ?? 0))
    }

    // MARK: - Deeplink

    public static func trackDeeplink(name: String) {
        track(eventWithCategory: .deeplink, name: name)
    }

    // MARK: - Public Share

    public static func trackAddToMyDrive() {
        track(eventWithCategory: .publicShareAction, name: "saveToKDrive")
    }

    public static func trackAddBulkToMykDrive() {
        track(eventWithCategory: .publicShareAction, name: "bulkSaveToKDrive")
    }

    public static func trackPublicSharePasswordAction() {
        track(eventWithCategory: .publicSharePasswordAction, name: "openInBrowser")
    }

    public static func trackUpsalePresented() {
        track(eventWithCategory: .publicShareAction, name: "adBottomSheet")
    }
}
