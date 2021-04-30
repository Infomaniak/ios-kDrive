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
import UserNotifications
import CocoaLumberjackSwift

public class NotificationsHelper {

    public static let uploadCategoryId = "com.kdrive.notification.upload"
    private static let uploadQueueCountNotificationId = "uploadQueueCount"
    private static let uploadDoneNotificationId = "uploadDone"
    private static let uploadPausedNotificationId = "uploadPaused"
    public static let previousUploadCountKey = "previousUploadCountKey"
    public static let parentIdKey = "parentIdKey"
    public static let generalCategoryId = "com.kdrive.notification.general"
    private static let migrateNotificationId = "migrate"

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
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
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

    public static func sendUploadDoneNotification(uploadId: String, parentId: Int?, filename: String?, error: DriveError? = nil) {
        let filename = filename == nil ? "Inconnu" : filename!
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = uploadCategoryId
        content.sound = .default

        // TODO: Different message if filename is nil
        if let error = error {
            content.title = KDriveCoreStrings.Localizable.errorUpload

            content.body = KDriveCoreStrings.Localizable.allUploadErrorDescription(filename, error.localizedDescription)
            content.userInfo[parentIdKey] = parentId
            sendImmediately(notification: content, id: uploadDoneNotificationId)
        } else {
            UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
                content.title = KDriveCoreStrings.Localizable.allUploadFinishedTitle
                let uploadDoneNotifications = notifications.filter({ $0.request.identifier == uploadDoneNotificationId })
                var previousCount = 0
                if uploadDoneNotifications.count > 0 {
                    previousCount = (uploadDoneNotifications.first?.request.content.userInfo[previousUploadCountKey] as? Int ?? 0) + 1
                    content.body = KDriveCoreStrings.Localizable.allUploadFinishedDescriptionPlural(previousCount)
                } else {
                    previousCount += 1
                    content.body = KDriveCoreStrings.Localizable.allUploadFinishedDescription(filename)
                }
                content.userInfo[previousUploadCountKey] = previousCount
                content.userInfo[parentIdKey] = parentId

                sendImmediately(notification: content, id: uploadDoneNotificationId)
            }
        }
    }

    public static func sendUploadQueueNotification(uploadCount: Int, parentId: Int) {
        if uploadCount == 0 {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [uploadQueueCountNotificationId])
        } else {
            let content = UNMutableNotificationContent()
            content.title = KDriveCoreStrings.Localizable.uploadInProgressTitle
            content.body = KDriveCoreStrings.Localizable.uploadInProgressNumberFile(uploadCount)
            content.categoryIdentifier = uploadCategoryId
            content.sound = .default
            content.userInfo[parentIdKey] = parentId
            sendImmediately(notification: content, id: uploadQueueCountNotificationId)
        }
    }

    public static func sendPausedUploadQueueNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Importation en pause"
        content.body = "Des importations sont toujours en cours dans kDrive. Elles ont été mise en pause et reprendront cette nuit ou quand vous relancerez l’app."
        content.categoryIdentifier = uploadCategoryId
        content.sound = .default
        sendImmediately(notification: content, id: uploadPausedNotificationId)
    }

    public static func sendMigrateNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveCoreStrings.Localizable.migrateNotificationTitle
        content.body = KDriveCoreStrings.Localizable.migrateNotificationDescription
        content.categoryIdentifier = generalCategoryId
        content.sound = .default
        sendImmediately(notification: content, id: migrateNotificationId)
    }

    private static func sendImmediately(notification: UNMutableNotificationContent, id: String) {
        if notification.categoryIdentifier == uploadCategoryId && !NotificationsHelper.importNotificationsEnabled {
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: notification, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

}
