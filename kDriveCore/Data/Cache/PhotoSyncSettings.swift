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
import RealmSwift

@objc public enum PhotoSyncMode: Int, RealmEnum {
    case new = 0
    case all = 1

    public var title: String {
        switch self {
        case .new:
            return KDriveCoreStrings.Localizable.syncSettingsSaveDateNowValue
        case .all:
            return KDriveCoreStrings.Localizable.syncSettingsSaveDateAllPictureValue
        }
    }
}

public class PhotoSyncSettings: Object {
    @objc public dynamic var userId: Int = -1
    @objc public dynamic var driveId: Int = -1
    @objc public dynamic var parentDirectoryId: Int = -1
    @objc public dynamic var lastSync = Date(timeIntervalSince1970: 0)
    @objc public dynamic var syncMode: PhotoSyncMode = .new
    @objc public dynamic var syncPicturesEnabled = true
    @objc public dynamic var syncVideosEnabled = true
    @objc public dynamic var syncScreenshotsEnabled = true
    @objc public dynamic var createDatedSubFolders = false
    @objc public dynamic var deleteAssetsAfterImport = false

    public init(userId: Int, driveId: Int, parentDirectoryId: Int, lastSync: Date, syncMode: PhotoSyncMode, syncPictures: Bool, syncVideos: Bool, syncScreenshots: Bool, createDatedSubFolders: Bool, deleteAssetsAfterImport: Bool) {
        self.userId = userId
        self.driveId = driveId
        self.parentDirectoryId = parentDirectoryId
        self.lastSync = lastSync
        self.syncMode = syncMode
        self.syncPicturesEnabled = syncPictures
        self.syncVideosEnabled = syncVideos
        self.syncScreenshotsEnabled = syncScreenshots
        self.createDatedSubFolders = createDatedSubFolders
        self.deleteAssetsAfterImport = deleteAssetsAfterImport
    }

    override public init() {}

    override public class func primaryKey() -> String? {
        return "userId"
    }

    public func isContentEqual(to settings: PhotoSyncSettings) -> Bool {
        return userId == settings.userId &&
            driveId == settings.driveId &&
            parentDirectoryId == settings.parentDirectoryId &&
            syncPicturesEnabled == settings.syncPicturesEnabled &&
            syncVideosEnabled == settings.syncVideosEnabled &&
            syncScreenshotsEnabled == settings.syncScreenshotsEnabled &&
            createDatedSubFolders == settings.createDatedSubFolders &&
            deleteAssetsAfterImport == settings.deleteAssetsAfterImport &&
            syncMode == settings.syncMode
    }
}
