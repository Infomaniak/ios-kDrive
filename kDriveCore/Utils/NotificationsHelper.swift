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

import CocoaLumberjackSwift
import Foundation
import UserNotifications

public enum NotificationsHelper {
    public static let uploadCategoryId = "com.kdrive.notification.upload"
    private static let uploadQueueCountNotificationId = "uploadQueueCount"
    private static let uploadDoneNotificationId = "uploadDone"
    private static let uploadPausedNotificationId = "uploadPaused"
    private static let disconnectedNotificationId = "accountDisconnected"
    public static let previousUploadCountKey = "previousUploadCountKey"
    public static let parentIdKey = "parentIdKey"
    public static let generalCategoryId = "com.kdrive.notification.general"
    private static let migrateNotificationId = "migrate"

    private struct SnackbarAction {
        let title: String
        let action: () -> Void
    }

    public static var isNotificationEnabled: Bool {
        return UserDefaults.shared.isNotificationEnabled
    }

    public static var importNotificationsEnabled: Bool {
        return isNotificationEnabled && UserDefaults.shared.importNotificationsEnabled
    }

    public static var sharingNotificationsEnabled: Bool {
        return isNotificationEnabled && UserDefaults.shared.sharingNotificationsEnabled
    }

    public static var newCommentNotificationsEnabled: Bool {
        return isNotificationEnabled && UserDefaults.shared.newCommentNotificationsEnabled
    }

    public static func askForPermissions() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional, .providesAppNotificationSettings]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
            if !granted {
                DDLogInfo("User has declined notifications")
            }
        }
    }

    public static func registerCategories() {
        let uploadCategory = UNNotificationCategory(identifier: uploadCategoryId, actions: [], intentIdentifiers: [], options: [])
        let migrateCategory = UNNotificationCategory(identifier: generalCategoryId, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories(Set([uploadCategory, migrateCategory]))
    }

    public static func sendUploadError(filename: String, parentId: Int, error: DriveError) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = uploadCategoryId
        content.sound = .default

        content.title = KDriveCoreStrings.Localizable.errorUpload
        content.body = KDriveCoreStrings.Localizable.allUploadErrorDescription(filename, error.localizedDescription)
        content.userInfo[parentIdKey] = parentId

        sendImmediately(notification: content, id: UUID().uuidString)
    }

    public static func sendUploadDoneNotification(filename: String, parentId: Int) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = uploadCategoryId
        content.sound = .default

        UNUserNotificationCenter.current().getDeliveredNotifications { _ in
            content.title = KDriveCoreStrings.Localizable.allUploadFinishedTitle
            content.body = KDriveCoreStrings.Localizable.allUploadFinishedDescription(filename)
            content.userInfo[parentIdKey] = parentId
            let action = SnackbarAction(title: "Locate") {
                NotificationCenter.default.post(name: .locateUploadActionTapped, object: nil, userInfo: ["parentId": parentId])
            }
            sendImmediately(notification: content, id: uploadDoneNotificationId, action: action)
        }
    }

    public static func sendUploadDoneNotification(uploadCount: Int, parentId: Int?) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [uploadDoneNotificationId])
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = uploadCategoryId
        content.sound = .default
        content.title = KDriveCoreStrings.Localizable.allUploadFinishedTitle
        content.body = KDriveCoreStrings.Localizable.allUploadFinishedDescriptionPlural(uploadCount)
        content.userInfo[parentIdKey] = parentId
        let action = SnackbarAction(title: "Locate") {
            NotificationCenter.default.post(name: .locateUploadActionTapped, object: nil, userInfo: ["parentId": parentId as Any])
        }
        sendImmediately(notification: content, id: uploadDoneNotificationId, action: action)
    }

    public static func sendPausedUploadQueueNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveCoreStrings.Localizable.uploadPausedTitle
        content.body = KDriveCoreStrings.Localizable.uploadPausedDescription
        content.categoryIdentifier = uploadCategoryId
        content.sound = .default
        sendImmediately(notification: content, id: uploadPausedNotificationId)
    }

    public static func sendDisconnectedNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveCoreStrings.Localizable.errorGeneric
        content.body = KDriveCoreStrings.Localizable.refreshTokenError
        content.categoryIdentifier = generalCategoryId
        content.sound = .default
        sendImmediately(notification: content, id: disconnectedNotificationId)
    }

    public static func sendMigrateNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveCoreStrings.Localizable.migrateNotificationTitle
        content.body = KDriveCoreStrings.Localizable.migrateNotificationDescription
        content.categoryIdentifier = generalCategoryId
        content.sound = .default
        sendImmediately(notification: content, id: migrateNotificationId)
    }

    private static func sendImmediately(notification: UNMutableNotificationContent, id: String, action: SnackbarAction? = nil) {
        DispatchQueue.main.async {
            if notification.categoryIdentifier == uploadCategoryId && !NotificationsHelper.importNotificationsEnabled {
                return
            }

            let isInBackground = Constants.isInExtension || UIApplication.shared.applicationState != .active

            if isInBackground {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: notification, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            } else {
                if let action = action {
                    IKSnackBar.make(message: notification.body, duration: .lengthLong, action: action.title, completion: action.action)?.show()
                } else {
                    IKSnackBar.make(message: notification.body, duration: .lengthLong)?.show()
                }
            }
        }
    }
}

public extension Notification.Name {
    static let locateUploadActionTapped = Notification.Name(rawValue: "kDriveLocateUploadActionTapped")
}
