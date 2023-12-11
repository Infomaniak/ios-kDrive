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
import InfomaniakCoreUI
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import Kingfisher
import StoreKit
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, AccountManagerDelegate {
    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook()

    private var reachabilityListener: ReachabilityListener!
    private static let currentStateVersion = 4
    private static let appStateVersionKey = "appStateVersionKey"
    private var shortcutItemToProcess: UIApplicationShortcutItem?

    var window: UIWindow?

    @LazyInjectService var lockHelper: AppLockHelper
    @LazyInjectService var infomaniakLogin: InfomaniakLogin
    @LazyInjectService var backgroundUploadSessionManager: BackgroundUploadSessionManager
    @LazyInjectService var backgroundDownloadSessionManager: BackgroundDownloadSessionManager
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var backgroundTaskScheduler: BGTaskScheduler
    @LazyInjectService var notificationHelper: NotificationsHelpable

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Logging.initLogging()
        Log.appDelegate("Application starting in foreground ? \(UIApplication.shared.applicationState != .background)")
        ImageCache.default.memoryStorage.config.totalCostLimit = Constants.memoryCacheSizeLimit
        reachabilityListener = ReachabilityListener.instance
        ApiEnvironment.current = .prod

        // Start audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            Log.appDelegate("Error while setting playback audio category", level: .error)
            SentryDebug.capture(error: error)
        }

        registerBackgroundTasks()

        // In some cases the application can show the old Nextcloud import notification badge
        UIApplication.shared.applicationIconBadgeNumber = 0
        notificationHelper.askForPermissions()
        notificationHelper.registerCategories()
        UNUserNotificationCenter.current().delegate = self

        window = UIWindow()
        setGlobalTint()
        let currentState = RootViewControllerState.getCurrentState()
        prepareRootViewController(currentState: currentState)

        if CommandLine.arguments.contains("testing") {
            UIView.setAnimationsEnabled(false)
        }

        window?.overrideUserInterfaceStyle = UserDefaults.shared.theme.interfaceStyle

        // Attach an observer to the payment queue.
        SKPaymentQueue.default().add(StoreObserver.shared)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocateUploadNotification),
            name: .locateUploadActionTapped,
            object: nil
        )
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDrive), name: .reloadDrive, object: nil)

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

        let state = UIApplication.shared.applicationState
        if state != .background {
            // Remove all notifications on App Opening
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }

        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            shortcutItemToProcess = shortcutItem
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
            group.leave()
        }

        // The documentation specifies `approximately five seconds [to] return` from applicationWillTerminate
        // Therefore to not display a crash feedback on TestFlight, we give up after 4.5 seconds
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 4.5) {
            group.leave()
        }

        group.enter()
        group.wait()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.appDelegate("Unable to register for remote notifications: \(error.localizedDescription)", level: .error)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Log.appDelegate("applicationDidEnterBackground")

        scheduleBackgroundRefresh()
        if UserDefaults.shared.isAppLockEnabled,
           !(window?.rootViewController?.isKind(of: LockedAppViewController.self) ?? false) {
            lockHelper.setTime()
        }
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        shortcutItemToProcess = shortcutItem
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Log.appDelegate("application performFetchWithCompletionHandler")

        handleBackgroundRefresh { newData in
            if newData {
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Log.appDelegate("application app open url\(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let params = components.queryItems else {
            Log.appDelegate("Failed to open URL: Invalid URL", level: .error)
            return false
        }

        @InjectService var accountManager: AccountManageable

        if components.path == "store",
           let userId = params.first(where: { $0.name == "userId" })?.value,
           let driveId = params.first(where: { $0.name == "driveId" })?.value {
            if var viewController = window?.rootViewController,
               let userId = Int(userId), let driveId = Int(driveId),
               let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId) {
                // Get presented view controller
                while let presentedViewController = viewController.presentedViewController {
                    viewController = presentedViewController
                }
                // Show store
                StorePresenter.showStore(from: viewController, driveFileManager: driveFileManager)
            }
            return true
        }
        return false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Log.appDelegate("applicationWillEnterForeground")

        @InjectService var uploadQueue: UploadQueue
        uploadQueue.pausedNotificationSent = false

        let currentState = RootViewControllerState.getCurrentState()
        prepareRootViewController(currentState: currentState)
        if case .mainViewController = currentState {
            UserDefaults.shared.numberOfConnections += 1
            launchSetup()
        }

        // Remove all notifications on App Opening
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Set global tint color
    private func setGlobalTint() {
        window?.tintColor = KDriveResourcesAsset.infomaniakColor.color
        UITabBar.appearance().unselectedItemTintColor = KDriveResourcesAsset.iconColor.color
        // Migration from old UserDefaults
        if UserDefaults.shared.legacyIsFirstLaunch {
            UserDefaults.shared.legacyIsFirstLaunch = UserDefaults.standard.legacyIsFirstLaunch
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if let shortcutItem = shortcutItemToProcess {
            @InjectService var accountManager: AccountManageable

            guard let rootViewController = window?.rootViewController as? MainTabViewController else {
                return
            }

            // Dismiss all view controllers presented
            rootViewController.dismiss(animated: false)

            guard let navController = rootViewController.selectedViewController as? UINavigationController,
                  let viewController = navController.topViewController,
                  let driveFileManager = accountManager.currentDriveFileManager else {
                return
            }

            switch shortcutItem.type {
            case Constants.applicationShortcutScan:
                let openMediaHelper = OpenMediaHelper(driveFileManager: driveFileManager)
                openMediaHelper.openScan(rootViewController, false)
                MatomoUtils.track(eventWithCategory: .shortcuts, name: "scan")
            case Constants.applicationShortcutSearch:
                let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
                viewController.present(
                    SearchViewController.instantiateInNavigationController(viewModel: viewModel),
                    animated: true
                )
                MatomoUtils.track(eventWithCategory: .shortcuts, name: "search")
            case Constants.applicationShortcutUpload:
                let openMediaHelper = OpenMediaHelper(driveFileManager: driveFileManager)
                openMediaHelper.openMedia(rootViewController, .library)
                MatomoUtils.track(eventWithCategory: .shortcuts, name: "upload")
            case Constants.applicationShortcutSupport:
                UIApplication.shared.open(URLConstants.support.url)
                MatomoUtils.track(eventWithCategory: .shortcuts, name: "support")
            default:
                break
            }

            // reset the shortcut item
            shortcutItemToProcess = nil
        }
    }

    func refreshCacheData(preload: Bool, isSwitching: Bool) {
        Log.appDelegate("refreshCacheData preload:\(preload) isSwitching:\(preload)")

        @InjectService var accountManager: AccountManageable
        let currentAccount = accountManager.currentAccount!
        let rootViewController = window?.rootViewController as? UpdateAccountDelegate

        if preload {
            updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
        } else {
            var token: ObservationToken?
            token = ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
                // Remove observer after 1 pass
                token?.cancel()
                DispatchQueue.global(qos: .utility).async {
                    self?.updateAvailableOfflineFiles(status: status)
                }
            }
        }

        Task {
            do {
                let oldDriveId = accountManager.currentDriveFileManager?.drive.objectId
                let account = try await accountManager.updateUser(for: currentAccount, registerToken: true)
                rootViewController?.didUpdateCurrentAccountInformations(account)

                if let oldDriveId,
                   let newDrive = DriveInfosManager.instance.getDrive(objectId: oldDriveId),
                   !newDrive.inMaintenance {
                    // The current drive is still usable, do not switch
                    restartUploadQueue()
                    return
                }

                let driveFileManager = try accountManager.getFirstAvailableDriveFileManager(for: account.userId)
                accountManager.setCurrentDriveForCurrentAccount(drive: driveFileManager.drive)
                showMainViewController(driveFileManager: driveFileManager)
                restartUploadQueue()
            } catch DriveError.NoDriveError.noDrive {
                let driveErrorNavigationViewController = DriveErrorViewController.instantiateInNavigationController(
                    errorType: .noDrive,
                    drive: nil
                )
                setRootViewController(driveErrorNavigationViewController)
            } catch DriveError.NoDriveError.blocked(let drive), DriveError.NoDriveError.maintenance(let drive) {
                let driveErrorNavigationViewController = DriveErrorViewController.instantiateInNavigationController(
                    errorType: drive.isInTechnicalMaintenance ? .maintenance : .blocked,
                    drive: drive
                )
                setRootViewController(driveErrorNavigationViewController)
            } catch {
                UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
                Log.appDelegate("Error while updating user account: \(error)", level: .error)
            }
        }
    }

    private func restartUploadQueue() {
        // Resolving an upload queue will restart it if this is the first time
        @InjectService var uploadQueue: UploadQueue

        backgroundUploadSessionManager.reconnectBackgroundTasks()
        DispatchQueue.global(qos: .utility).async {
            Log.appDelegate("Restart queue")
            @InjectService var photoUploader: PhotoLibraryUploader
            _ = photoUploader.scheduleNewPicturesForUpload()

            @InjectService var uploadQueue: UploadQueue
            uploadQueue.rebuildUploadQueueFromObjectsInRealm()
        }
    }

    func updateAvailableOfflineFiles(status: ReachabilityListener.NetworkStatus) {
        Log.appDelegate("updateAvailableOfflineFiles")

        guard status != .offline && (!UserDefaults.shared.isWifiOnly || status == .wifi) else {
            return
        }

        @InjectService var accountManager: AccountManageable
        for drive in DriveInfosManager.instance.getDrives(for: accountManager.currentUserId, sharedWithMe: false) {
            guard let driveFileManager = accountManager.getDriveFileManager(for: drive) else {
                continue
            }

            Task {
                do {
                    try await driveFileManager.updateAvailableOfflineFiles()
                } catch {
                    // Silently handle error
                    Log.appDelegate(
                        "Error while fetching offline files activities in [\(drive.id) - \(drive.name)]: \(error)",
                        level: .error
                    )
                }
            }
        }
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     sourceApplication: String?,
                     annotation: Any) -> Bool {
        Log.appDelegate("application open url:\(url)) sourceApplication:\(sourceApplication)")
        return infomaniakLogin.handleRedirectUri(url: url)
    }

    func setRootViewController(_ vc: UIViewController,
                               animated: Bool = true) {
        guard animated, let window else {
            self.window?.rootViewController = vc
            self.window?.makeKeyAndVisible()
            return
        }

        window.rootViewController = vc
        window.makeKeyAndVisible()
        UIView.transition(with: window, duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil,
                          completion: nil)
    }

    func present(file: File, driveFileManager: DriveFileManager, office: Bool = false) {
        guard let rootViewController = window?.rootViewController as? MainTabViewController else {
            return
        }

        // Dismiss all view controllers presented
        rootViewController.dismiss(animated: false) {
            // Select Files tab
            rootViewController.selectedIndex = 1

            guard let navController = rootViewController.selectedViewController as? UINavigationController,
                  let viewController = navController.topViewController as? FileListViewController else {
                return
            }

            if !file.isRoot && viewController.viewModel.currentDirectory.id != file.id {
                // Pop to root
                navController.popToRootViewController(animated: false)
                // Present file
                guard let fileListViewController = navController.topViewController as? FileListViewController else { return }
                if office {
                    OnlyOfficeViewController.open(driveFileManager: driveFileManager,
                                                  file: file,
                                                  viewController: fileListViewController)
                } else {
                    let filePresenter = FilePresenter(viewController: fileListViewController)
                    filePresenter.present(driveFileManager: driveFileManager,
                                          file: file,
                                          files: [file],
                                          normalFolderHierarchy: false)
                }
            }
        }
    }

    @objc func handleLocateUploadNotification(_ notification: Notification) {
        @InjectService var accountManager: AccountManageable
        if let parentId = notification.userInfo?["parentId"] as? Int,
           let driveFileManager = accountManager.currentDriveFileManager,
           let folder = driveFileManager.getCachedFile(id: parentId) {
            present(file: folder, driveFileManager: driveFileManager)
        }
    }

    @objc func reloadDrive(_ notification: Notification) {
        Task { @MainActor in
            self.refreshCacheData(preload: false, isSwitching: false)
        }
    }

    // MARK: - Account manager delegate

    func currentAccountNeedsAuthentication() {
        setRootViewController(SwitchUserViewController.instantiateInNavigationController())
    }

    // MARK: - State restoration

    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        Log.appDelegate("application shouldSaveApplicationState")

        coder.encode(AppDelegate.currentStateVersion, forKey: AppDelegate.appStateVersionKey)
        return true
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        let encodedVersion = coder.decodeInteger(forKey: AppDelegate.appStateVersionKey)
        @InjectService var accountManager: AccountManageable

        return AppDelegate
            .currentStateVersion == encodedVersion &&
            !(UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty)
    }

    // MARK: - User activity

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        Log.appDelegate("application continue restorationHandler")
        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
            return false
        }

        // Check for specific URL components that you need.
        return UniversalLinksHelper.handlePath(components.path, appDelegate: self)
    }
}

// MARK: - User notification center delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // In Foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        _ = notification.request.content.userInfo

        // Change this to your preferred presentation option
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
                @InjectService var accountManager: AccountManageable

                switch response.actionIdentifier {
                case UNNotificationDefaultActionIdentifier:
                    // Notification tapped: open parent folder
                    if let parentId,
                       let driveFileManager = accountManager.currentDriveFileManager,
                       let folder = driveFileManager.getCachedFile(id: parentId) {
                        present(file: folder, driveFileManager: driveFileManager)
                    }
                default:
                    break
                }
            } else if response.notification.request.content.categoryIdentifier == NotificationsHelper.CategoryIdentifier
                .photoSyncError {
                // Show photo sync settings
                guard let rootViewController = window?.rootViewController as? MainTabViewController else {
                    return
                }

                // Dismiss all view controllers presented
                rootViewController.dismiss(animated: false)
                // Select Menu tab
                rootViewController.selectedIndex = 4

                guard let navController = rootViewController.selectedViewController as? UINavigationController else {
                    return
                }

                let photoSyncSettingsViewController = PhotoSyncSettingsViewController.instantiate()
                navController.popToRootViewController(animated: false)
                navController.pushViewController(photoSyncSettingsViewController, animated: true)
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

// MARK: - Navigation

extension AppDelegate {
    var topMostViewController: UIViewController? {
        var topViewController = window?.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }
}
