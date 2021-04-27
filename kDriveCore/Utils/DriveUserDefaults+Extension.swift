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

    private static let keyCurrentDriveId = "currentDriveId"
    private static let keyFileSortMode = "fileSortMode"
    private static let keyFilesListStyle = "filesListStyle"
    private static let keyCurrentDriveUserId = "currentDriveUserId"
    private static let keyWifiOnly = "wifiOnly"
    private static let keyRecentSearches = "recentSearches"
    private static let keyNumberOfConnection = "numberOfConnection"
    private static let keyAppLock = "appLock"
    private static let keyUpdateLater = "updateLater"
    private static let keyMigrated = "migrated"
    private static let keyMigrationPhotoSyncEnabled = "migrationPhotoSyncEnabled"
    private static let keyNotificationsEnabled = "notificationsEnabled"
    private static let keyImportNotificationsEnabled = "importNotificationsEnabled"
    private static let keySharingNotificationsEnabled = "sharingNotificationsEnabled"
    private static let keyNewCommentNotificationsEnabled = "newCommentNotificationsEnabled"
    private static let keyDidDemoSwipe = "didDemoSwipe"

    private static var appGroupDefaults = UserDefaults(suiteName: AccountManager.appGroup)!

    public static func store(currentDriveId: String) {
        appGroupDefaults.set(currentDriveId, forKey: keyCurrentDriveId)
    }

    public static func getCurrentDriveId() -> String {
        return appGroupDefaults.string(forKey: keyCurrentDriveId) ?? ""
    }

    public static func store(sortMode: SortType) {
        appGroupDefaults.set(sortMode.rawValue, forKey: keyFileSortMode)
    }

    public static func getSortMode() -> SortType {
        return SortType(rawValue: appGroupDefaults.string(forKey: keyFileSortMode) ?? "") ?? .nameAZ
    }

    public static func store(listStyle: ListStyle) {
        appGroupDefaults.set(listStyle.rawValue, forKey: keyFilesListStyle)
    }

    public static func getListStyle() -> ListStyle {
        return ListStyle(rawValue: appGroupDefaults.string(forKey: keyFilesListStyle) ?? "") ?? .list
    }

    static func store(currentDriveUserId: Int) {
        appGroupDefaults.set(currentDriveUserId, forKey: keyCurrentDriveUserId)
    }

    static func getCurrentDriveUserId() -> Int {
        return appGroupDefaults.integer(forKey: keyCurrentDriveUserId)
    }

    public static func store(wifiOnly: Bool) {
        appGroupDefaults.set(wifiOnly, forKey: keyWifiOnly)
    }

    public static func isWifiOnlyMode() -> Bool {
        return appGroupDefaults.bool(forKey: keyWifiOnly)
    }

    public static func store(recentSearches: [String]) {
        appGroupDefaults.set(recentSearches, forKey: keyRecentSearches)
    }

    public static func getRecentSearches() -> [String] {
        return appGroupDefaults.stringArray(forKey: keyRecentSearches) ?? []
    }

    public static func store(numberOfConnection: Int) {
        appGroupDefaults.set(numberOfConnection, forKey: keyNumberOfConnection)
    }

    public static func getNumberOfConnection() -> Int {
        return appGroupDefaults.integer(forKey: keyNumberOfConnection)
    }

    public static func store(appLock: Bool) {
        appGroupDefaults.set(appLock, forKey: keyAppLock)
    }

    public static func isAppLockMode() -> Bool {
        return appGroupDefaults.bool(forKey: keyAppLock)
    }

    public static func store(updateLater: Bool) {
        appGroupDefaults.set(updateLater, forKey: keyUpdateLater)
    }

    public static func updateLater() -> Bool {
        return appGroupDefaults.bool(forKey: keyUpdateLater)
    }

    static func store(migrated: Bool) {
        appGroupDefaults.set(migrated, forKey: keyMigrated)
    }

    static func migrated() -> Bool {
        return appGroupDefaults.bool(forKey: keyMigrated)
    }

    static func store(migrationPhotoSyncEnabled: Bool) {
        appGroupDefaults.set(migrationPhotoSyncEnabled, forKey: keyMigrationPhotoSyncEnabled)
    }

    static func wasPhotoSyncEnabledBeforeMigration() -> Bool {
        return appGroupDefaults.bool(forKey: keyMigrationPhotoSyncEnabled)
    }

    public static func store(notificationsEnabled: Bool) {
        appGroupDefaults.setValue(notificationsEnabled, forKey: keyNotificationsEnabled)
    }

    public static func notificationsEnabled() -> Bool {
        if appGroupDefaults.object(forKey: keyNotificationsEnabled) == nil {
            appGroupDefaults.setValue(true, forKey: keyNotificationsEnabled)
        }
        return appGroupDefaults.bool(forKey: keyNotificationsEnabled)
    }

    public static func store(importNotificationEnabled: Bool) {
        appGroupDefaults.setValue(importNotificationEnabled, forKey: keyImportNotificationsEnabled)
    }

    public static func importNotificationsEnabled() -> Bool {
        if appGroupDefaults.object(forKey: keyImportNotificationsEnabled) == nil {
            appGroupDefaults.setValue(true, forKey: keyImportNotificationsEnabled)
        }
        return appGroupDefaults.bool(forKey: keyImportNotificationsEnabled)
    }

    public static func store(sharingNotificationEnabled: Bool) {
        appGroupDefaults.setValue(sharingNotificationEnabled, forKey: keySharingNotificationsEnabled)
    }

    public static func sharingNotificationsEnabled() -> Bool {
        if appGroupDefaults.object(forKey: keySharingNotificationsEnabled) == nil {
            appGroupDefaults.setValue(true, forKey: keySharingNotificationsEnabled)
        }
        return appGroupDefaults.bool(forKey: keySharingNotificationsEnabled)
    }

    public static func store(newCommentNotificationEnabled: Bool) {
        appGroupDefaults.setValue(newCommentNotificationEnabled, forKey: keyNewCommentNotificationsEnabled)
    }

    public static func newCommentNotificationsEnabled() -> Bool {
        if appGroupDefaults.object(forKey: keyNewCommentNotificationsEnabled) == nil {
            appGroupDefaults.setValue(true, forKey: keyNewCommentNotificationsEnabled)
        }
        return appGroupDefaults.bool(forKey: keyNewCommentNotificationsEnabled)
    }

    public static func store(didDemoSwipe: Bool) {
        appGroupDefaults.setValue(didDemoSwipe, forKey: keyDidDemoSwipe)
    }

    public static func didDemoSwipe() -> Bool {
        return appGroupDefaults.bool(forKey: keyDidDemoSwipe)
    }
}
