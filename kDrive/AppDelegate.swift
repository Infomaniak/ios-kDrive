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
import InfomaniakCore
import InfomaniakCoreUIKit
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import Kingfisher
import os.log
import StoreKit
import UIKit
import UserNotifications
import VersionChecker

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook(context: .app)

    private var reachabilityListener: ReachabilityListener!

    @LazyInjectService var infomaniakLogin: InfomaniakLogin
    @LazyInjectService var notificationHelper: NotificationsHelpable
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var backgroundTasksService: BackgroundTasksServiceable
    @LazyInjectService var appRestorationService: AppRestorationServiceable
    @LazyInjectService var appNavigable: AppNavigable
    @LazyInjectService var backgroundDownloadSessionManager: BackgroundDownloadSessionManager
    @LazyInjectService var backgroundUploadSessionManager: BackgroundUploadSessionManager

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Logging.initLogging()
        Log.appDelegate("Application starting in foreground ? \(UIApplication.shared.applicationState != .background)")

        ImageCache.default.memoryStorage.config.totalCostLimit = Constants.ImageCache.memorySizeLimit
        // Must define a limit, unlimited otherwise
        ImageCache.default.diskStorage.config.sizeLimit = Constants.ImageCache.diskSizeLimit

        reachabilityListener = ReachabilityListener.instance
        ApiEnvironment.current = .prod

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
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        // For iOS 10 display notification (sent via APNS)
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in
            // META: keep SonarCloud happy
        }
        application.registerForRemoteNotifications()

        // swiftlint:disable force_try
        Task {
            try! await Task.sleep(nanoseconds:5_000_000_000)
            print("coucou")
            // a public share password protected
            let somePublicShare = URL(string: "https://kdrive.infomaniak.com/app/share/140946/34844cea-db8d-4d87-b66f-e944e9759a2e")

            await UniversalLinksHelper.handleURL(somePublicShare!)
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Log.appDelegate("applicationWillTerminate")

        // Remove the observer.
        SKPaymentQueue.default().remove(StoreObserver.shared)

        // Gracefully suspend upload/download queue before exiting.
        // Running operations will go on, but at least no more operations will start
        DownloadQueue.instance.suspendAllOperations()
        DownloadQueue.instance.cancelAllOperations()

        @InjectService var uploadQueue: UploadQueueable
        uploadQueue.suspendAllOperations()
        uploadQueue.rescheduleRunningOperations()

        // Await on upload queue to terminate gracefully, if time allows for it.
        let group = TolerantDispatchGroup()
        uploadQueue.waitForCompletion {
            // Clean temp files once the upload queue is stoped if needed
            @LazyInjectService var freeSpaceService: FreeSpaceService
            freeSpaceService.auditCache()

            group.leave()
        }

        // The documentation specifies `approximately five seconds [to] return` from applicationWillTerminate
        // Therefore to not display a crash feedback on TestFlight, we give up after 4.5 seconds
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + AppDelegateConstants.closeApplicationGiveUpTime) {
            group.leave()
        }

        group.enter()
        group.wait()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.appDelegate("Unable to register for remote notifications: \(error.localizedDescription)", level: .error)
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     sourceApplication: String?,
                     annotation: Any) -> Bool {
        Log.appDelegate("application open url:\(url)) sourceApplication:\(sourceApplication)")
        return infomaniakLogin.handleRedirectUri(url: url)
    }
}

// MARK: - User notification center delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // In Foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        _ = notification.request.content.userInfo

        completionHandler([.alert, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        switch response.notification.request.trigger {
        case is UNPushNotificationTrigger:
            processPushNotification(response.notification)
        default:
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
            } else {
                // Handle other notification types...
            }
        }

        completionHandler()
    }

    private func processPushNotification(_ notification: UNNotification) {
        UIApplication.shared.applicationIconBadgeNumber = 0
//        PROCESS NOTIFICATION
//        let userInfo = notification.request.content.userInfo
//
//        let parentId = Int(userInfo["parentId"] as? String ?? "")
//        if let parentId = parentId,
//           let driveFileManager = accountManager.currentDriveFileManager,
//           let folder = driveFileManager.getCachedFile(id: parentId) {
//            present(file: folder, driveFileManager: driveFileManager)
//        }
//
//        Messaging.messaging().appDidReceiveMessage(userInfo)
    }
}
