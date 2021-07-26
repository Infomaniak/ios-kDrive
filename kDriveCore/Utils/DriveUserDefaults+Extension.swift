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

extension UserDefaults {

    public static let shared = UserDefaults(suiteName: AccountManager.appGroup)!

    private enum Keys: String {
        case currentDriveId
        case fileSortMode
        case filesListStyle
        case currentDriveUserId
        case wifiOnly
        case recentSearches
        case numberOfConnection
        case appLock
        case updateLater
        case migrated
        case migrationPhotoSyncEnabled
        case notificationsEnabled
        case importNotificationsEnabled
        case sharingNotificationsEnabled
        case newCommentNotificationsEnabled
        case didDemoSwipe
        case lastSelectedDrive
        case lastSelectedDirectory
        case theme
        case photoSortMode
        case betaInviteDisplayed
        case lastSyncDateOfflineFiles
    }

    private func key(_ key: Keys) -> String {
        return key.rawValue
    }

    public var currentDriveId: Int {
        get {
            return integer(forKey: key(.currentDriveId))
        }
        set {
            set(newValue, forKey: key(.currentDriveId))
        }
    }

    public var currentDriveUserId: Int {
        get {
            return integer(forKey: key(.currentDriveUserId))
        }
        set {
            set(newValue, forKey: key(.currentDriveUserId))
        }
    }

    public var sortType: SortType {
        get {
            return SortType(rawValue: string(forKey: key(.fileSortMode)) ?? "") ?? .nameAZ
        }
        set {
            set(newValue.rawValue, forKey: key(.fileSortMode))
        }
    }

    public var listStyle: ListStyle {
        get {
            return ListStyle(rawValue: string(forKey: key(.filesListStyle)) ?? "") ?? .list
        }
        set {
            set(newValue.rawValue, forKey: key(.filesListStyle))
        }
    }

    public var isWifiOnly: Bool {
        get {
            return bool(forKey: key(.wifiOnly))
        }
        set {
            set(newValue, forKey: key(.wifiOnly))
        }
    }

    public var recentSearches: [String] {
        get {
            return stringArray(forKey: key(.recentSearches)) ?? []
        }
        set {
            set(newValue, forKey: key(.recentSearches))
        }
    }

    public var numberOfConnections: Int {
        get {
            return integer(forKey: key(.numberOfConnection))
        }
        set {
            set(newValue, forKey: key(.numberOfConnection))
        }
    }

    public var isAppLockEnabled: Bool {
        get {
            return bool(forKey: key(.appLock))
        }
        set {
            set(newValue, forKey: key(.appLock))
        }
    }

    public var updateLater: Bool {
        get {
            return bool(forKey: key(.updateLater))
        }
        set {
            set(newValue, forKey: key(.updateLater))
        }
    }

    public var isMigrated: Bool {
        get {
            return bool(forKey: key(.migrated))
        }
        set {
            set(newValue, forKey: key(.migrated))
        }
    }

    public var wasPhotoSyncEnabledBeforeMigration: Bool {
        get {
            return bool(forKey: key(.migrationPhotoSyncEnabled))
        }
        set {
            set(newValue, forKey: key(.migrationPhotoSyncEnabled))
        }
    }

    public var isNotificationEnabled: Bool {
        get {
            if object(forKey: key(.notificationsEnabled)) == nil {
                set(true, forKey: key(.notificationsEnabled))
            }
            return bool(forKey: key(.notificationsEnabled))
        }
        set {
            set(newValue, forKey: key(.notificationsEnabled))
        }
    }

    public var importNotificationsEnabled: Bool {
        get {
            if object(forKey: key(.importNotificationsEnabled)) == nil {
                set(true, forKey: key(.importNotificationsEnabled))
            }
            return bool(forKey: key(.importNotificationsEnabled))
        }
        set {
            set(newValue, forKey: key(.importNotificationsEnabled))
        }
    }

    public var sharingNotificationsEnabled: Bool {
        get {
            if object(forKey: key(.sharingNotificationsEnabled)) == nil {
                set(true, forKey: key(.sharingNotificationsEnabled))
            }
            return bool(forKey: key(.sharingNotificationsEnabled))
        }
        set {
            set(newValue, forKey: key(.sharingNotificationsEnabled))
        }
    }

    public var newCommentNotificationsEnabled: Bool {
        get {
            if object(forKey: key(.newCommentNotificationsEnabled)) == nil {
                set(true, forKey: key(.newCommentNotificationsEnabled))
            }
            return bool(forKey: key(.newCommentNotificationsEnabled))
        }
        set {
            set(newValue, forKey: key(.newCommentNotificationsEnabled))
        }
    }

    public var didDemoSwipe: Bool {
        get {
            return bool(forKey: key(.didDemoSwipe))
        }
        set {
            set(newValue, forKey: key(.didDemoSwipe))
        }
    }

    public var lastSelectedDrive: Int {
        get {
            return integer(forKey: key(.lastSelectedDrive))
        }
        set {
            set(newValue, forKey: key(.lastSelectedDrive))
        }
    }

    public var lastSelectedDirectory: Int {
        get {
            return integer(forKey: key(.lastSelectedDirectory))
        }
        set {
            set(newValue, forKey: key(.lastSelectedDirectory))
        }
    }

    public var theme: Theme {
        get {
            guard let theme = object(forKey: key(.theme)) as? String else {
                setValue(Theme.system.rawValue, forKey: key(.theme))
                return Theme.system
            }
            return Theme(rawValue: theme)!
        }
        set {
            setValue(newValue.rawValue, forKey: key(.theme))
        }
    }

    public var photoSortMode: PhotoSortMode {
        get {
            return PhotoSortMode(rawValue: string(forKey: key(.photoSortMode)) ?? "") ?? .month
        }
        set {
            return set(newValue.rawValue, forKey: key(.photoSortMode))
        }
    }
    
    public var betaInviteDisplayed: Bool {
        get {
            return bool(forKey: key(.betaInviteDisplayed))
        }
        set {
            set(newValue, forKey: key(.betaInviteDisplayed))
		}
	}

    public var lastSyncDateOfflineFiles: Int {
        get {
            return integer(forKey: key(.lastSyncDateOfflineFiles))
        }
        set {
            setValue(newValue, forKey: key(.lastSyncDateOfflineFiles))
        }
    }
}
