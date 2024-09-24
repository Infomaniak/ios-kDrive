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

public extension UserDefaults.Keys {
    static let currentDriveId = UserDefaults.Keys(rawValue: "currentDriveId")
    static let fileSortMode = UserDefaults.Keys(rawValue: "fileSortMode")
    static let filesListStyle = UserDefaults.Keys(rawValue: "filesListStyle")
    static let currentDriveUserId = UserDefaults.Keys(rawValue: "currentDriveUserId")
    static let wifiOnly = UserDefaults.Keys(rawValue: "wifiOnly")
    static let recentSearches = UserDefaults.Keys(rawValue: "recentSearches")
    static let numberOfConnection = UserDefaults.Keys(rawValue: "numberOfConnection")
    static let appLock = UserDefaults.Keys(rawValue: "appLock")
    static let migrated = UserDefaults.Keys(rawValue: "migrated")
    static let migrationPhotoSyncEnabled = UserDefaults.Keys(rawValue: "migrationPhotoSyncEnabled")
    static let notificationsEnabled = UserDefaults.Keys(rawValue: "notificationsEnabled")
    static let importNotificationsEnabled = UserDefaults.Keys(rawValue: "importNotificationsEnabled")
    static let sharingNotificationsEnabled = UserDefaults.Keys(rawValue: "sharingNotificationsEnabled")
    static let newCommentNotificationsEnabled = UserDefaults.Keys(rawValue: "newCommentNotificationsEnabled")
    static let generalNotificationEnabled = UserDefaults.Keys(rawValue: "generalNotificationEnabled")
    static let didDemoSwipe = UserDefaults.Keys(rawValue: "didDemoSwipe")
    static let lastSelectedUser = UserDefaults.Keys(rawValue: "lastSelectedUser")
    static let lastSelectedDrive = UserDefaults.Keys(rawValue: "lastSelectedDrive")
    static let lastSelectedDirectory = UserDefaults.Keys(rawValue: "lastSelectedDirectory")
    static let lastSelectedTab = UserDefaults.Keys(rawValue: "lastSelectedTab")
    static let theme = UserDefaults.Keys(rawValue: "theme")
    static let photoSortMode = UserDefaults.Keys(rawValue: "photoSortMode")
    static let betaInviteDisplayed = UserDefaults.Keys(rawValue: "betaInviteDisplayed")
    static let lastSyncDateOfflineFiles = UserDefaults.Keys(rawValue: "lastSyncDateOfflineFiles")
    static let fileProviderExtension = UserDefaults.Keys(rawValue: "fileProviderExtension")
    static let categoryPanelDisplayed = UserDefaults.Keys(rawValue: "categoryPanelDisplayed")
    static let homeListStyle = UserDefaults.Keys(rawValue: "homeListStyle")
    static let selectedHomeIndex = UserDefaults.Keys(rawValue: "selectedHomeIndex")
    static let fpStorageVersion = UserDefaults.Keys(rawValue: "fpStorageVersion")
    static let importPhotoFormat = UserDefaults.Keys(rawValue: "importPhotoFormat")
    static let syncMod = UserDefaults.Keys(rawValue: "syncMod")
    static let matomoAuthorized = UserDefaults.Keys(rawValue: "matomoAuthorized")
    static let sentryAuthorized = UserDefaults.Keys(rawValue: "sentryAuthorized")
}

public extension UserDefaults {
    static let shared = UserDefaults(suiteName: AccountManager.appGroup)!

    var currentDriveId: Int {
        get {
            return integer(forKey: key(.currentDriveId))
        }
        set {
            set(newValue, forKey: key(.currentDriveId))
        }
    }

    var currentDriveUserId: Int {
        get {
            return integer(forKey: key(.currentDriveUserId))
        }
        set {
            set(newValue, forKey: key(.currentDriveUserId))
        }
    }

    var sortType: SortType {
        get {
            return SortType(rawValue: string(forKey: key(.fileSortMode)) ?? "") ?? .nameAZ
        }
        set {
            set(newValue.rawValue, forKey: key(.fileSortMode))
        }
    }

    var listStyle: ListStyle {
        get {
            return ListStyle(rawValue: string(forKey: key(.filesListStyle)) ?? "") ?? .list
        }
        set {
            set(newValue.rawValue, forKey: key(.filesListStyle))
        }
    }

    var isWifiOnly: Bool {
        get {
            return bool(forKey: key(.wifiOnly))
        }
        set {
            set(newValue, forKey: key(.wifiOnly))
        }
    }

    var recentSearches: [String] {
        get {
            return stringArray(forKey: key(.recentSearches)) ?? []
        }
        set {
            set(newValue, forKey: key(.recentSearches))
        }
    }

    var numberOfConnections: Int {
        get {
            return integer(forKey: key(.numberOfConnection))
        }
        set {
            set(newValue, forKey: key(.numberOfConnection))
        }
    }

    var isAppLockEnabled: Bool {
        get {
            return bool(forKey: key(.appLock))
        }
        set {
            set(newValue, forKey: key(.appLock))
        }
    }

    var isMigrated: Bool {
        get {
            return bool(forKey: key(.migrated))
        }
        set {
            set(newValue, forKey: key(.migrated))
        }
    }

    var wasPhotoSyncEnabledBeforeMigration: Bool {
        get {
            return bool(forKey: key(.migrationPhotoSyncEnabled))
        }
        set {
            set(newValue, forKey: key(.migrationPhotoSyncEnabled))
        }
    }

    var isNotificationEnabled: Bool {
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

    var importNotificationsEnabled: Bool {
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

    var sharingNotificationsEnabled: Bool {
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

    var newCommentNotificationsEnabled: Bool {
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

    var generalNotificationEnabled: Bool {
        get {
            if object(forKey: key(.generalNotificationEnabled)) == nil {
                set(true, forKey: key(.generalNotificationEnabled))
            }
            return bool(forKey: key(.generalNotificationEnabled))
        }
        set {
            set(newValue, forKey: key(.generalNotificationEnabled))
        }
    }

    var didDemoSwipe: Bool {
        get {
            return bool(forKey: key(.didDemoSwipe))
        }
        set {
            set(newValue, forKey: key(.didDemoSwipe))
        }
    }

    var lastSelectedUser: Int {
        get {
            return integer(forKey: key(.lastSelectedUser))
        }
        set {
            set(newValue, forKey: key(.lastSelectedUser))
        }
    }

    var lastSelectedDrive: Int {
        get {
            return integer(forKey: key(.lastSelectedDrive))
        }
        set {
            set(newValue, forKey: key(.lastSelectedDrive))
        }
    }

    var lastSelectedDirectory: Int {
        get {
            return integer(forKey: key(.lastSelectedDirectory))
        }
        set {
            set(newValue, forKey: key(.lastSelectedDirectory))
        }
    }

    var lastSelectedTab: Int? {
        get {
            return integer(forKey: key(.lastSelectedTab))
        }
        set {
            set(newValue, forKey: key(.lastSelectedTab))
        }
    }

    var theme: Theme {
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

    var photoSortMode: PhotoSortMode {
        get {
            return PhotoSortMode(rawValue: string(forKey: key(.photoSortMode)) ?? "") ?? .month
        }
        set {
            return set(newValue.rawValue, forKey: key(.photoSortMode))
        }
    }

    var betaInviteDisplayed: Bool {
        get {
            return bool(forKey: key(.betaInviteDisplayed))
        }
        set {
            set(newValue, forKey: key(.betaInviteDisplayed))
        }
    }

    var lastSyncDateOfflineFiles: Int {
        get {
            return integer(forKey: key(.lastSyncDateOfflineFiles))
        }
        set {
            setValue(newValue, forKey: key(.lastSyncDateOfflineFiles))
        }
    }

    var isFileProviderExtensionEnabled: Bool {
        get {
            if object(forKey: key(.fileProviderExtension)) == nil {
                set(true, forKey: key(.fileProviderExtension))
            }
            return bool(forKey: key(.fileProviderExtension))
        }
        set {
            set(newValue, forKey: key(.fileProviderExtension))
        }
    }

    var categoryPanelDisplayed: Bool {
        get {
            return bool(forKey: key(.categoryPanelDisplayed))
        }
        set {
            set(newValue, forKey: key(.categoryPanelDisplayed))
        }
    }

    var homeListStyle: ListStyle {
        get {
            return ListStyle(rawValue: string(forKey: key(.homeListStyle)) ?? "") ?? .list
        }
        set {
            set(newValue.rawValue, forKey: key(.homeListStyle))
        }
    }

    var fpStorageVersion: Int {
        get {
            return integer(forKey: key(.fpStorageVersion))
        }
        set {
            set(newValue, forKey: key(.fpStorageVersion))
        }
    }

    var importPhotoFormat: PhotoFileFormat {
        get {
            return PhotoFileFormat(rawValue: integer(forKey: key(.importPhotoFormat))) ?? .jpg
        }
        set {
            set(newValue.rawValue, forKey: key(.importPhotoFormat))
        }
    }

    var syncMod: SyncMod {
        get {
            if let rawValue = object(forKey: key(.syncMod)) as? String,
               let mod = SyncMod(rawValue: rawValue) {
                return mod
            }
            return .onlyWifi
        }
        set {
            set(newValue.rawValue, forKey: key(.syncMod))
        }
    }

    var isMatomoAuthorized: Bool {
        get {
            if object(forKey: key(.matomoAuthorized)) == nil {
                set(DefaultPreferences.matomoAuthorized, forKey: key(.matomoAuthorized))
            }
            return bool(forKey: key(.matomoAuthorized))
        }
        set {
            set(newValue, forKey: key(.matomoAuthorized))
        }
    }

    var isSentryAuthorized: Bool {
        get {
            if object(forKey: key(.sentryAuthorized)) == nil {
                set(DefaultPreferences.sentryAuthorized, forKey: key(.sentryAuthorized))
            }
            return bool(forKey: key(.sentryAuthorized))
        }
        set {
            set(newValue, forKey: key(.sentryAuthorized))
        }
    }
}

public enum DefaultPreferences {
    public static let matomoAuthorized = true
    public static let sentryAuthorized = true
}
