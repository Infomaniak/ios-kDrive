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
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveResources
import UserNotifications

public protocol NotificationsHelpable {
    func askForPermissions()

    func registerCategories()

    /// Send a notification that we cannot perform an operation, as we do not have enough space
    func sendNotEnoughSpaceForUpload(filename: String)

    func sendGenericUploadError(filename: String, parentId: Int, error: DriveError, uploadFileId: String)

    func sendUploadDoneNotification(filename: String, parentId: Int)

    func sendUploadDoneNotification(uploadCount: Int, parentId: Int?)

    func sendPausedUploadQueueNotification()

    func sendDisconnectedNotification()

    func sendPhotoSyncErrorNotification()

    func sendFailedUpload(failedUpload: Int, totalUpload: Int)

    func sendDeleteUploadedPhotosNotification(photosToDelete: Int)
}

public struct NotificationsHelper: NotificationsHelpable {
    @LazyInjectService private var appContextService: AppContextServiceable

    public enum CategoryIdentifier {
        public static let general = "com.kdrive.notification.general"
        public static let upload = "com.kdrive.notification.upload"
        public static let photoSyncError = "com.kdrive.notification.syncError"
    }

    public enum UserInfoKey {
        public static let previousUploadCount = "previousUploadCountKey"
        public static let parentId = "parentIdKey"
    }

    private enum NotificationIdentifier {
        static let uploadQueueCount = "uploadQueueCount"
        static let uploadDone = "uploadDone"
        static let uploadPaused = "uploadPaused"
        static let disconnected = "accountDisconnected"
        static let migrate = "migrate"
        static let photoSyncError = "photoSyncError"
        static let deleteUploadedPhotos = "deleteUploadedPhotos"
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

    public init() {
        // used by factory
    }

    // MARK: - Service setup

    public func askForPermissions() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional, .providesAppNotificationSettings]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
            if !granted {
                DDLogInfo("User has declined notifications")
            }
        }
    }

    public func registerCategories() {
        let uploadCategory = UNNotificationCategory(
            identifier: CategoryIdentifier.upload,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let migrateCategory = UNNotificationCategory(
            identifier: CategoryIdentifier.general,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories(Set([uploadCategory, migrateCategory]))
    }

    // MARK: - Send Notifications

    public func sendNotEnoughSpaceForUpload(filename: String) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryIdentifier.upload
        content.sound = .default
        content.title = KDriveResourcesStrings.Localizable.errorDeviceStorage
        content.body = KDriveResourcesStrings.Localizable.allUploadErrorDescription(
            filename,
            KDriveResourcesStrings.Localizable.errorDeviceStorage
        )

        sendImmediately(notification: content, id: UUID().uuidString)
    }

    public func sendGenericUploadError(filename: String, parentId: Int, error: DriveError, uploadFileId: String) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryIdentifier.upload
        content.sound = .default

        content.title = KDriveResourcesStrings.Localizable.errorUpload
        content.body = KDriveResourcesStrings.Localizable.allUploadErrorDescription(filename, error.localizedDescription)
        content.userInfo[UserInfoKey.parentId] = parentId

        sendImmediately(notification: content, id: UUID().uuidString)

        // Error metadata
        let metadata: [String: Any] = ["uploadFileId": uploadFileId,
                                       "error.type": error.type,
                                       "error.code": error.code,
                                       "error.localizedDescription": error.localizedDescription,
                                       "error.userInfo": error.userInfo ?? "nil",
                                       "error.underlyingError": error.underlyingError ?? "nil"]

        // We capture all upload errors presented to the user, with underlyingError if any
        SentryDebug.uploadNotificationError(metadata)

        // Add a breadcrumb
        SentryDebug.uploadNotificationBreadcrumb(metadata)
    }

    public func sendUploadDoneNotification(filename: String, parentId: Int) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryIdentifier.upload
        content.sound = .default

        UNUserNotificationCenter.current().getDeliveredNotifications { _ in
            content.title = KDriveResourcesStrings.Localizable.allUploadFinishedTitle
            content.body = KDriveResourcesStrings.Localizable.allUploadFinishedDescription(filename)
            content.userInfo[UserInfoKey.parentId] = parentId
            let action = IKSnackBar.Action(title: KDriveResourcesStrings.Localizable.locateButton) {
                NotificationCenter.default.post(name: .locateUploadActionTapped, object: nil, userInfo: ["parentId": parentId])
            }
            sendImmediately(notification: content, id: NotificationIdentifier.uploadDone, action: action)
        }
    }

    public func sendUploadDoneNotification(uploadCount: Int, parentId: Int?) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [NotificationIdentifier.uploadDone])
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryIdentifier.upload
        content.sound = .default
        content.title = KDriveResourcesStrings.Localizable.allUploadFinishedTitle
        content.body = KDriveResourcesStrings.Localizable.allUploadFinishedDescriptionPlural(uploadCount)
        content.userInfo[UserInfoKey.parentId] = parentId
        let action = IKSnackBar.Action(title: KDriveResourcesStrings.Localizable.locateButton) {
            NotificationCenter.default.post(name: .locateUploadActionTapped, object: nil, userInfo: ["parentId": parentId as Any])
        }
        sendImmediately(notification: content, id: NotificationIdentifier.uploadDone, action: action)
    }

    public func sendPausedUploadQueueNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveResourcesStrings.Localizable.uploadPausedTitle
        content.body = KDriveResourcesStrings.Localizable.uploadPausedDescription
        content.categoryIdentifier = CategoryIdentifier.upload
        content.sound = .default
        sendImmediately(notification: content, id: NotificationIdentifier.uploadPaused)
    }

    public func sendDisconnectedNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveResourcesStrings.Localizable.errorGeneric
        content.body = KDriveResourcesStrings.Localizable.refreshTokenError
        content.categoryIdentifier = CategoryIdentifier.general
        content.sound = .default
        sendImmediately(notification: content, id: NotificationIdentifier.disconnected)
    }

    public func sendPhotoSyncErrorNotification() {
        let content = UNMutableNotificationContent()
        content.title = KDriveResourcesStrings.Localizable.errorGeneric
        content.body = KDriveResourcesStrings.Localizable.uploadFolderNotFoundSyncDisabledError
        content.categoryIdentifier = CategoryIdentifier.photoSyncError
        content.sound = .default
        sendImmediately(notification: content, id: NotificationIdentifier.photoSyncError)
    }

    public func sendFailedUpload(failedUpload: Int, totalUpload: Int) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = CategoryIdentifier.upload
        content.sound = .default
        content.title = KDriveResourcesStrings.Localizable.errorGeneric
        if failedUpload <= 1 {
            content.body = KDriveResourcesStrings.Localizable.uploadImportedFailedAmount(totalUpload)
        } else {
            content.body = KDriveResourcesStrings.Localizable.uploadImportedFailedAmountPlural(totalUpload, failedUpload)
        }

        sendImmediately(notification: content, id: UUID().uuidString)
    }

    public func sendDeleteUploadedPhotosNotification(photosToDelete: Int) {
        let content = UNMutableNotificationContent()
        content.title = KDriveResourcesStrings.Localizable.deleteUploadedPhotosTitle(photosToDelete)
        content.body = KDriveResourcesStrings.Localizable.deleteUploadedPhotosDescription
        content.categoryIdentifier = CategoryIdentifier.general
        content.sound = .default
        sendImmediately(notification: content, id: NotificationIdentifier.deleteUploadedPhotos)
    }

    // MARK: - Private

    private func sendImmediately(notification: UNMutableNotificationContent, id: String, action: IKSnackBar.Action? = nil) {
        Task { @MainActor in
            if notification.categoryIdentifier == CategoryIdentifier.upload && !NotificationsHelper.importNotificationsEnabled {
                return
            }

            let isInBackground = appContextService.isExtension || UIApplication.shared.applicationState != .active

            if isInBackground {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: id, content: notification, trigger: trigger)
                try? await UNUserNotificationCenter.current().add(request)
            } else {
                UIConstants.showSnackBar(message: notification.body, duration: .lengthLong, action: action)
            }
        }
    }
}
