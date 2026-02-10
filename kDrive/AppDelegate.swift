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

import Atlantis
import AVFoundation
import BackgroundTasks
import CocoaLumberjackSwift
import InAppTwoFactorAuthentication
import InfomaniakCore
import InfomaniakCoreUIKit
import InfomaniakDI
import InfomaniakLogin
import InfomaniakNotifications
import kDriveCore
import kDriveResources
import Kingfisher
import os.log
import Sentry
import StoreKit
import UIKit
import UserNotifications
import VersionChecker

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// periphery:ignore - Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook(context: .app)

    @LazyInjectService var infomaniakLogin: InfomaniakLogin
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var backgroundTasksService: BackgroundTasksServiceable
    @LazyInjectService var appNavigable: AppNavigable
    @LazyInjectService var backgroundDownloadSessionManager: BackgroundDownloadSessionManager
    @LazyInjectService var backgroundUploadSessionManager: BackgroundUploadSessionManager
    @LazyInjectService var downloadQueue: DownloadQueueable
    @LazyInjectService var tokenStore: TokenStore
    @LazyInjectService var notificationService: InfomaniakNotifications

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Logging.initLogging()
        Log.appDelegate("Application starting in foreground ? \(UIApplication.shared.applicationState != .background)")

        ImageCache.default.memoryStorage.config.totalCostLimit = Constants.ImageCache.memorySizeLimit
        // Must define a limit, unlimited otherwise
        ImageCache.default.diskStorage.config.sizeLimit = Constants.ImageCache.diskSizeLimit
        let sessionConfiguration = ImageDownloader.default.sessionConfiguration
        sessionConfiguration.httpAdditionalHeaders = [
            "User-Agent": Constants.userAgent
        ]
        ImageDownloader.default.sessionConfiguration = sessionConfiguration

        _ = ReachabilityListener.instance

        // Start audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            Log.appDelegate("Error while setting playback audio category", level: .error)
            SentryDebug.capture(error: error)
        }

        backgroundTasksService.registerBackgroundTasks()

        // In some cases the application can show the old Nextcloud import notification badge
        UIApplication.shared.applicationIconBadgeNumber = 0
        notificationHelper.askForPermissions()
        notificationHelper.registerCategories()
        UNUserNotificationCenter.current().delegate = self

        if CommandLine.arguments.contains("testing") {
            UIView.setAnimationsEnabled(false)
        }

        // Attach an observer to the payment queue.
        SKPaymentQueue.default().add(StoreObserver.shared)

        return true
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Log.appDelegate("application didFinishLaunchingWithOptions")

        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Log.appDelegate("applicationWillTerminate")

        addCacheBreadcrumbSynchronously(message: "applicationWillTerminate")

        // Remove the observer.
        SKPaymentQueue.default().remove(StoreObserver.shared)

        // Gracefully suspend upload/download queue before exiting.
        // Running operations will go on, but at least no more operations will start
        downloadQueue.suspendAllOperations()
        downloadQueue.cancelAllOperations()

        @InjectService var uploadService: UploadServiceable
        uploadService.suspendAllOperations()
        uploadService.rescheduleRunningOperations()

        // Await on upload queue to terminate gracefully, if time allows for it.
        let group = TolerantDispatchGroup()
        uploadService.waitForCompletion {
            self.addCacheBreadcrumbSynchronously(message: "will cleanup cache")

            // Clean temp files once the upload queue is stoped if needed
            @LazyInjectService var freeSpaceService: FreeSpaceService
            freeSpaceService.auditCache()

            self.addCacheBreadcrumbSynchronously(message: "did cleanup cache")

            group.leave()
        }

        // The documentation specifies `approximately five seconds [to] return` from applicationWillTerminate
        // Therefore to not display a crash feedback on TestFlight, we give up after 4.5 seconds
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + AppDelegateConstants.closeApplicationGiveUpTime) {
            self.addCacheBreadcrumbSynchronously(message: "interrupt cleanup cache", level: .error)
            group.leave()
        }

        group.enter()
        group.wait()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        for token in tokenStore.getAllTokens().values {
            Task {
                /* Because of a backend issue we can't register the notification token directly after the creation or refresh of
                 an API token. We wait at least 15 seconds before trying to register. */
                try? await Task.sleep(nanoseconds: 15_000_000_000)

                let userApiFetcher = accountManager.getApiFetcher(for: token.userId, token: token.apiToken)
                await notificationService.updateRemoteNotificationsToken(tokenData: deviceToken,
                                                                         userApiFetcher: userApiFetcher,
                                                                         updatePolicy: .always)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.appDelegate("Unable to register for remote notifications: \(error.localizedDescription)", level: .error)
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     sourceApplication: String?,
                     annotation: Any) -> Bool {
        Log.appDelegate("application open url:\(url)) sourceApplication:\(String(describing: sourceApplication))")
        return infomaniakLogin.handleRedirectUri(url: url)
    }

    @inline(__always) private func addCacheBreadcrumbSynchronously(message: String, level: SentryLevel = .info) {
        let breadcrumb = Breadcrumb(level: level, category: SentryDebug.Category.cacheCleanup.rawValue)
        breadcrumb.message = message
        SentrySDK.addBreadcrumb(breadcrumb)
    }
}

// MARK: - User notification center delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let handledByTwoFA = await handleTwoFactorAuthenticationNotification(notification)
        if handledByTwoFA {
            return []
        }

        return [.list, .banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if response.notification.request.content.categoryIdentifier == NotificationsHelper.CategoryIdentifier.upload {
            // Upload notification
            let parentId = userInfo[NotificationsHelper.UserInfoKey.parentId] as? Int

            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                // Notification tapped: open parent folder
                if let parentId,
                   let driveFileManager = accountManager.currentDriveFileManager,
                   let folder = driveFileManager.getCachedFile(id: parentId) {
                    appNavigable.present(file: folder, driveFileManager: driveFileManager)
                }
            default:
                break
            }
        } else if response.notification.request.content.categoryIdentifier == NotificationsHelper.CategoryIdentifier
            .photoSyncError {
            // Show photo sync settings
            appNavigable.showPhotoSyncSettings()
        }

        completionHandler()
    }

    func handleTwoFactorAuthenticationNotification(_ notification: UNNotification) async -> Bool {
        @InjectService var inAppTwoFactorAuthenticationManager: InAppTwoFactorAuthenticationManagerable

        guard let userId = inAppTwoFactorAuthenticationManager.handleRemoteNotification(notification) else {
            return false
        }

        let accounts = accountManager.accounts

        guard !accounts.isEmpty else {
            UIApplication.shared.unregisterForRemoteNotifications()
            return false
        }

        guard let account = accountManager.account(for: userId),
              let user = await accountManager.userProfileStore.getUserProfile(id: userId) else {
            return false
        }

        let apiFetcher = accountManager.getApiFetcher(for: userId, token: account)
        let session = InAppTwoFactorAuthenticationSession(user: user, apiFetcher: apiFetcher)

        inAppTwoFactorAuthenticationManager.checkConnectionAttempts(using: session)

        return true
    }
}
