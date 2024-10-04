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
import kDriveResources
import RealmSwift

public enum PhotoSyncMode: Int, PersistableEnum {
    case new = 0
    case all = 1
    case fromDate = 2

    public var title: String {
        switch self {
        case .new:
            return KDriveResourcesStrings.Localizable.syncSettingsSaveDateNowValue
        case .all:
            return KDriveResourcesStrings.Localizable.syncSettingsSaveDateAllPictureValue
        case .fromDate:
            return KDriveResourcesStrings.Localizable.syncSettingsSaveDateFromDateValue
        }
    }
}

public final class PhotoSyncSettings: Object {
    @Persisted(primaryKey: true) public var userId = UUID().uuidString.hashValue
    @Persisted public var driveId: Int
    @Persisted public var parentDirectoryId: Int
    @Persisted public var lastSync = Date(timeIntervalSince1970: 0)
    @Persisted public var syncMode: PhotoSyncMode = .new
    @Persisted public var fromDate = Date()
    @Persisted public var syncPicturesEnabled = true
    @Persisted public var syncVideosEnabled = true
    @Persisted public var syncScreenshotsEnabled = true
    @Persisted public var createDatedSubFolders = false
    @Persisted public var deleteAssetsAfterImport = false
    @Persisted public var photoFormat: PhotoFileFormat = .jpg
    @Persisted public var wifiSync: SyncMode = .wifiAndMobileData

    public init(userId: Int,
                driveId: Int,
                parentDirectoryId: Int,
                lastSync: Date,
                syncMode: PhotoSyncMode,
                fromDate: Date,
                syncPictures: Bool,
                syncVideos: Bool,
                syncScreenshots: Bool,
                createDatedSubFolders: Bool,
                deleteAssetsAfterImport: Bool,
                photoFormat: PhotoFileFormat,
                wifiSync: SyncMode) {
        super.init()
        self.userId = userId
        self.driveId = driveId
        self.parentDirectoryId = parentDirectoryId
        self.lastSync = lastSync
        self.syncMode = syncMode
        self.fromDate = fromDate
        syncPicturesEnabled = syncPictures
        syncVideosEnabled = syncVideos
        syncScreenshotsEnabled = syncScreenshots
        self.createDatedSubFolders = createDatedSubFolders
        self.deleteAssetsAfterImport = deleteAssetsAfterImport
        self.photoFormat = photoFormat
        self.wifiSync = wifiSync
    }

    override public init() {
        // Required by Realm
        super.init()
        // primary key is set as default value
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
            syncMode == settings.syncMode &&
            fromDate == settings.fromDate &&
            photoFormat == settings.photoFormat &&
            wifiSync == settings.wifiSync
    }
}
