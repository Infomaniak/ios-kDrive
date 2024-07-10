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
import kDriveCore
import MatomoTracker

enum MatomoUtils {
    static let shared: MatomoTracker = {
        let tracker = MatomoTracker(siteId: "8", baseURL: URLConstants.matomo.url)

        #if DEBUG
        tracker.isOptedOut = true
        #endif

        @InjectService var accountManager: AccountManageable
        tracker.userId = String(accountManager.currentUserId)
        return tracker
    }()

    enum Views: String {
        case shareAndRights, save, search, uploadQueue, preview, menu, settings, store, security

        var displayName: String {
            return rawValue.capitalized
        }
    }

    enum EventCategory: String {
        case newElement, fileListFileAction, picturesFileAction, fileInfo, shareAndRights, colorFolder, categories, search,
             fileList, comment, drive, account, settings, photoSync, home, displayList, inApp, trash,
             dropbox, preview, mediaPlayer, shortcuts, appReview
    }

    enum UserAction: String {
        case click, input
    }

    enum MediaPlayerType: String {
        case audio, video
    }

    static func connectUser() {
        @InjectService var accountManager: AccountManageable
        shared.userId = String(accountManager.currentUserId)
    }

    static func track(view: [String]) {
        shared.track(view: view)
    }

    static func track(eventWithCategory category: EventCategory, action: UserAction = .click, name: String, value: Float? = nil) {
        shared.track(eventWithCategory: category.rawValue, action: action.rawValue, name: name, value: value)
    }

    static func track(eventWithCategory category: EventCategory, action: UserAction = .click, name: String, value: Bool) {
        track(eventWithCategory: category, action: action, name: name, value: value ? 1.0 : 0.0)
    }

    static func trackBulkEvent(eventWithCategory category: EventCategory, name: String, numberOfItems number: Int) {
        track(eventWithCategory: category, action: .click,
              name: "bulk\(number == 1 ? "Single" : "")\(name)", value: Float(number))
    }

    // MARK: - DropBox

    static func trackDropBoxSettings(_ settings: DropBoxSettings, passwordEnabled: Bool) {
        track(eventWithCategory: .dropbox, name: "switchEmailOnFileImport", value: settings.emailWhenFinished)
        track(eventWithCategory: .dropbox, name: "switchProtectWithPassword", value: passwordEnabled)
        track(eventWithCategory: .dropbox, name: "switchExpirationDate", value: settings.validUntil != nil)
        track(eventWithCategory: .dropbox, name: "switchLimitStorageSpace", value: settings.limitFileSize != nil)
        if let size = settings.limitFileSize {
            track(eventWithCategory: .dropbox, action: .input, name: "changeLimitStorage", value: Float(size.toGibibytes))
        }
    }

    // MARK: - Photo Sync

    static func trackPhotoSync(isEnabled: Bool, with settings: PhotoSyncSettings) {
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

    // MARK: - Share annd Rights

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

    // MARK: - Preview file

    static func trackPreview(file: File) {
        MatomoUtils.track(eventWithCategory: .preview, name: "preview\(file.convertedType.rawValue.capitalized)")
    }

    // MARK: - Media player

    static func trackMediaPlayer(playMedia: MatomoUtils.MediaPlayerType) {
        track(eventWithCategory: .mediaPlayer, name: "play\(playMedia.rawValue.capitalized)")
    }

    static func trackMediaPlayer(leaveAt percentage: Double?) {
        track(eventWithCategory: .mediaPlayer, name: "duration", value: Float(percentage ?? 0))
    }

    // MARK: - File action

    #if !ISEXTENSION

    static func trackFileAction(action: FloatingPanelAction, file: File, fromPhotoList: Bool) {
        let category: EventCategory = fromPhotoList ? .picturesFileAction : .fileListFileAction
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

    static func trackBuklAction(action: FloatingPanelAction, files: [File], fromPhotoList: Bool) {
        let numberOfFiles = files.count
        let category: EventCategory = fromPhotoList ? .picturesFileAction : .fileListFileAction
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
