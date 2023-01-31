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
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import Kingfisher
import Sentry
import StoreKit
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, AccountManagerDelegate {
    var window: UIWindow?
    
    /// Making sure the DI is registered at a very early stage of the app launch.
    let dependencyInjectionHook = EarlyDIHook()

    private var reachabilityListener: ReachabilityListener!
    private static let currentStateVersion = 2
    private static let appStateVersionKey = "appStateVersionKey"

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Logging.initLogging()
        DDLogInfo("Application starting in foreground ? \(UIApplication.shared.applicationState != .background)")
        ImageCache.default.memoryStorage.config.totalCostLimit = Constants.memoryCacheSizeLimit
        InfomaniakLogin.initWith(clientId: DriveApiFetcher.clientId)
        reachabilityListener = ReachabilityListener.instance
        ApiEnvironment.current = .prod

        // Start audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            DDLogError("Error while setting playback audio category")
            SentrySDK.capture(error: error)
        }

        registerBackgroundTasks()

        // In some cases the application can show the old Nextcloud import notification badge
        UIApplication.shared.applicationIconBadgeNumber = 0
        NotificationsHelper.askForPermissions()
        NotificationsHelper.registerCategories()
        UNUserNotificationCenter.current().delegate = self

        if UIApplication.shared.applicationState != .background {
            launchSetup()
        }

        if CommandLine.arguments.contains("testing") {
            UIView.setAnimationsEnabled(false)
        }

        window?.overrideUserInterfaceStyle = UserDefaults.shared.theme.interfaceStyle

        // Attach an observer to the payment queue.
        SKPaymentQueue.default().add(StoreObserver.shared)

        NotificationCenter.default.addObserver(self, selector: #selector(handleLocateUploadNotification), name: .locateUploadActionTapped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDrive), name: .reloadDrive, object: nil)

        return true
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        // For iOS 10 display notification (sent via APNS)
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }
        application.registerForRemoteNotifications()

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Remove the observer.
        SKPaymentQueue.default().remove(StoreObserver.shared)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DDLogError("Unable to register for remote notifications: \(error.localizedDescription)")
    }

    func handleBackgroundRefresh(completion: @escaping (Bool) -> Void) {
        // User installed the app but never logged in
        let accountManager = InjectService<AccountManager>().wrappedValue
        if accountManager.accounts.isEmpty {
            completion(false)
            return
        }

        _ = PhotoLibraryUploader.instance.addNewPicturesToUploadQueue()
        let uploadQueue = InjectService<UploadQueue>().wrappedValue
        uploadQueue.waitForCompletion {
            completion(true)
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundRefresh()
        if UserDefaults.shared.isAppLockEnabled,
           !(window?.rootViewController?.isKind(of: LockedAppViewController.self) ?? false) {
            AppLockHelper.shared.setTime()
        }
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Old Nextcloud based app only supports this way for background fetch so it's the only place it will be called in the background.
        if MigrationHelper.canMigrate() {
            NotificationsHelper.sendMigrateNotification()
            return
        }

        handleBackgroundRefresh { newData in
            if newData {
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let params = components.queryItems else {
            DDLogError("Failed to open URL: Invalid URL")
            return false
        }

        let accountManager = InjectService<AccountManager>().wrappedValue

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
        let uploadQueue = InjectService<UploadQueue>().wrappedValue
        uploadQueue.pausedNotificationSent = false
        launchSetup()
    }

    private func launchSetup() {
        // Set global tint color
        window?.tintColor = KDriveResourcesAsset.infomaniakColor.color
        UITabBar.appearance().unselectedItemTintColor = KDriveResourcesAsset.iconColor.color
        // Migration from old UserDefaults
        if UserDefaults.shared.isFirstLaunch {
            UserDefaults.shared.isFirstLaunch = UserDefaults.standard.isFirstLaunch
        }

        let accountManager = InjectService<AccountManager>().wrappedValue
        if MigrationHelper.canMigrate() && accountManager.accounts.isEmpty {
            window?.rootViewController = MigrationViewController.instantiate()
            window?.makeKeyAndVisible()
        } else if UserDefaults.shared.isFirstLaunch || accountManager.accounts.isEmpty {
            if !(window?.rootViewController?.isKind(of: OnboardingViewController.self) ?? false) {
                KeychainHelper.deleteAllTokens()
                window?.rootViewController = OnboardingViewController.instantiate()
                window?.makeKeyAndVisible()
            }
            // Clean File Provider domains on first launch in case we had some dangling
            DriveInfosManager.instance.deleteAllFileProviderDomains()
        } else if UserDefaults.shared.isAppLockEnabled && AppLockHelper.shared.isAppLocked {
            window?.rootViewController = LockedAppViewController.instantiate()
            window?.makeKeyAndVisible()
        } else {
            UserDefaults.shared.numberOfConnections += 1
            // Show launch floating panel
            let launchPanelsController = LaunchPanelsController()
            if let viewController = window?.rootViewController {
                launchPanelsController.pickAndDisplayPanel(viewController: viewController)
            }
            // Request App Store review
            if UserDefaults.shared.numberOfConnections == 10 {
                if #available(iOS 14.0, *) {
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                } else {
                    SKStoreReviewController.requestReview()
                }
            }
            // Refresh data
            refreshCacheData(preload: false, isSwitching: false)
            uploadEditedFiles()
            // Ask to remove uploaded pictures
            if let toRemoveItems = PhotoLibraryUploader.instance.getPicturesToRemove() {
                let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalDeletePhotosTitle,
                                                    message: KDriveResourcesStrings.Localizable.modalDeletePhotosDescription,
                                                    action: KDriveResourcesStrings.Localizable.buttonDelete,
                                                    destructive: true,
                                                    loading: false) {
                    // Proceed with removal
                    PhotoLibraryUploader.instance.removePicturesFromPhotoLibrary(toRemoveItems)
                }
                DispatchQueue.main.async {
                    self.window?.rootViewController?.present(alert, animated: true)
                }
            }
        }
    }

    func refreshCacheData(preload: Bool, isSwitching: Bool) {
        let accountManager = InjectService<AccountManager>().wrappedValue
        let currentAccount = accountManager.currentAccount!
        let rootViewController = window?.rootViewController as? SwitchAccountDelegate

        if preload {
            DispatchQueue.main.async {
                // if isSwitching {
                rootViewController?.didSwitchCurrentAccount(currentAccount)
                /* } else {
                     rootViewController?.didUpdateCurrentAccountInformations(currentAccount)
                 } */
            }
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

        let uploadQueue = InjectService<UploadQueue>().wrappedValue
        Task {
            do {
                let (_, switchedDrive) = try await accountManager.updateUser(for: currentAccount, registerToken: true)
                // if isSwitching {
                rootViewController?.didSwitchCurrentAccount(currentAccount)
                /* } else {
                     rootViewController?.didUpdateCurrentAccountInformations(currentAccount)
                 } */
                if let drive = switchedDrive,
                   let driveFileManager = accountManager.getDriveFileManager(for: drive),
                   !drive.maintenance {
                    (rootViewController as? SwitchDriveDelegate)?.didSwitchDriveFileManager(newDriveFileManager: driveFileManager)
                }

                if let currentDrive = accountManager.getDrive(for: accountManager.currentUserId, driveId: accountManager.currentDriveId),
                   currentDrive.maintenance {
                    if let nextAvailableDrive = DriveInfosManager.instance.getDrives(for: currentAccount.userId).first(where: { !$0.maintenance }),
                       let driveFileManager = accountManager.getDriveFileManager(for: nextAvailableDrive) {
                        accountManager.setCurrentDriveForCurrentAccount(drive: nextAvailableDrive)
                        (rootViewController as? SwitchDriveDelegate)?.didSwitchDriveFileManager(newDriveFileManager: driveFileManager)
                    } else {
                        let driveErrorViewControllerNav = DriveErrorViewController.instantiateInNavigationController()
                        let driveErrorViewController = driveErrorViewControllerNav.viewControllers.first as? DriveErrorViewController
                        driveErrorViewController?.driveErrorViewType = currentDrive.isInTechnicalMaintenance ? .maintenance : .blocked
                        if DriveInfosManager.instance.getDrives(for: currentAccount.userId).count == 1 {
                            driveErrorViewController?.drive = currentDrive
                        }
                        setRootViewController(driveErrorViewControllerNav)
                    }
                }

                uploadQueue.resumeAllOperations()
                uploadQueue.addToQueueFromRealm()
                BackgroundUploadSessionManager.instance.reconnectBackgroundTasks()
                DispatchQueue.global(qos: .utility).async {
                    _ = PhotoLibraryUploader.instance.addNewPicturesToUploadQueue()
                }
            } catch {
                UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
                DDLogError("Error while updating user account: \(error)")
            }
        }
    }

    private func uploadEditedFiles() {
        guard let folderURL = DriveFileManager.constants.openInPlaceDirectoryURL,
              FileManager.default.fileExists(atPath: folderURL.path) else {
            return
        }

        let accountManager = InjectService<AccountManager>().wrappedValue
        let group = DispatchGroup()
        var shouldCleanFolder = false
        let driveFolders = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)) ?? []
        // Hierarchy inside folderURL should be /driveId/fileId/fileName.extension
        for driveFolder in driveFolders {
            // Read drive folder
            let driveFolderURL = folderURL.appendingPathComponent(driveFolder)
            guard let driveId = Int(driveFolder),
                  let drive = DriveInfosManager.instance.getDrive(id: driveId, userId: accountManager.currentUserId),
                  let fileFolders = try? FileManager.default.contentsOfDirectory(atPath: driveFolderURL.path) else {
                DDLogInfo("[OPEN-IN-PLACE UPLOAD] Could not infer drive from \(driveFolderURL)")
                continue
            }

            for fileFolder in fileFolders {
                // Read file folder
                let fileFolderURL = driveFolderURL.appendingPathComponent(fileFolder)
                guard let fileId = Int(fileFolder),
                      let driveFileManager = accountManager.getDriveFileManager(for: drive),
                      let file = driveFileManager.getCachedFile(id: fileId) else {
                    DDLogInfo("[OPEN-IN-PLACE UPLOAD] Could not infer file from \(fileFolderURL)")
                    continue
                }

                let fileURL = fileFolderURL.appendingPathComponent(file.name)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    // Compare modification date
                    let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let modificationDate = attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
                    if modificationDate > file.lastModifiedAt {
                        // Copy and upload file
                        let uploadFile = UploadFile(parentDirectoryId: file.parentId,
                                                    userId: accountManager.currentUserId,
                                                    driveId: driveId,
                                                    url: fileURL,
                                                    name: file.name,
                                                    conflictOption: .replace,
                                                    shouldRemoveAfterUpload: false)
                        group.enter()
                        shouldCleanFolder = true
                        let uploadQueue = InjectService<UploadQueue>().wrappedValue
                        var observationToken: ObservationToken?
                        observationToken = uploadQueue.observeFileUploaded(self,
                                                                           fileId: uploadFile.id) { [fileId = file.id] uploadFile, _ in
                            observationToken?.cancel()
                            if let error = uploadFile.error {
                                shouldCleanFolder = false
                                DDLogError("[OPEN-IN-PLACE UPLOAD] Error while uploading: \(error)")
                            } else {
                                // Update file to get the new modification date
                                Task {
                                    let file = try await driveFileManager.file(id: fileId, forceRefresh: true)
                                    try? FileManager.default.setAttributes([.modificationDate: file.lastModifiedAt],
                                                                           ofItemAtPath: file.localUrl.path)
                                    driveFileManager.notifyObserversWith(file: file)
                                }
                            }
                            group.leave()
                        }
                        uploadQueue.addToQueue(file: uploadFile)
                    }
                }
            }
        }

        // Clean folder after completing all uploads
        group.notify(queue: DispatchQueue.global(qos: .utility)) {
            if shouldCleanFolder {
                DDLogInfo("[OPEN-IN-PLACE UPLOAD] Cleaning folder")
                try? FileManager.default.removeItem(at: folderURL)
            }
        }
    }

    func updateAvailableOfflineFiles(status: ReachabilityListener.NetworkStatus) {
        guard status != .offline && (!UserDefaults.shared.isWifiOnly || status == .wifi) else {
            return
        }

        let accountManager = InjectService<AccountManager>().wrappedValue
        for drive in DriveInfosManager.instance.getDrives(for: accountManager.currentUserId, sharedWithMe: false) {
            guard let driveFileManager = accountManager.getDriveFileManager(for: drive) else {
                continue
            }

            Task {
                do {
                    try await driveFileManager.updateAvailableOfflineFiles()
                } catch {
                    // Silently handle error
                    DDLogError("Error while fetching offline files activities in [\(drive.id) - \(drive.name)]: \(error)")
                }
            }
        }
    }

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        DDLogInfo("[Background Session] background session relaunched \(identifier)")
        if identifier == DownloadQueue.backgroundIdentifier {
            BackgroundDownloadSessionManager.instance.backgroundCompletionHandler = completionHandler
        } else if identifier.hasSuffix(UploadQueue.backgroundBaseIdentifier) {
            BackgroundUploadSessionManager.instance.handleEventsForBackgroundURLSession(identifier: identifier,
                                                                                        completionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     sourceApplication: String?,
                     annotation: Any) -> Bool {
        return InfomaniakLogin.handleRedirectUri(url: url)
    }

    func setRootViewController(_ vc: UIViewController,
                               animated: Bool = true) {
        guard animated, let window = window else {
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
        let accountManager = InjectService<AccountManager>().wrappedValue
        if let parentId = notification.userInfo?["parentId"] as? Int,
           let driveFileManager = accountManager.currentDriveFileManager,
           let folder = driveFileManager.getCachedFile(id: parentId) {
            present(file: folder, driveFileManager: driveFileManager)
        }
    }

    @objc func reloadDrive(_ notification: Notification) {
        DispatchQueue.main.async {
            self.refreshCacheData(preload: false, isSwitching: false)
        }
    }

    // MARK: - Account manager delegate

    func currentAccountNeedsAuthentication() {
        setRootViewController(SwitchUserViewController.instantiateInNavigationController())
    }

    // MARK: - State restoration

    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        coder.encode(AppDelegate.currentStateVersion, forKey: AppDelegate.appStateVersionKey)
        return true
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        let encodedVersion = coder.decodeInteger(forKey: AppDelegate.appStateVersionKey)
        let accountManager = InjectService<AccountManager>().wrappedValue

        return AppDelegate.currentStateVersion == encodedVersion && !(UserDefaults.shared.isFirstLaunch || accountManager.accounts.isEmpty)
    }

    // MARK: - User activity

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
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
                let accountManager = InjectService<AccountManager>().wrappedValue

                switch response.actionIdentifier {
                case UNNotificationDefaultActionIdentifier:
                    // Notification tapped: open parent folder
                    if let parentId = parentId,
                       let driveFileManager = accountManager.currentDriveFileManager,
                       let folder = driveFileManager.getCachedFile(id: parentId) {
                        present(file: folder, driveFileManager: driveFileManager)
                    }
                default:
                    break
                }
            } else if response.notification.request.content.categoryIdentifier == NotificationsHelper.CategoryIdentifier.photoSyncError {
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

/// Something that loads the DI on init
 public struct EarlyDIHook {

    public init() {
        // setup DI ASAP
        FactoryService.setupDependencyInjection()
    }
 }
