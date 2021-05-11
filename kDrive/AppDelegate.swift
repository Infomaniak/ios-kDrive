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

import UIKit
import AVFoundation
import UserNotifications
import InfomaniakLogin
import InfomaniakCore
import Atlantis
import Kingfisher
import kDriveCore
import BackgroundTasks
import CocoaLumberjackSwift
import StoreKit
import Sentry

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, AccountManagerDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    private var accountManager: AccountManager!
    private var uploadQueue: UploadQueue!
    private var reachabilityListener: ReachabilityListener!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logging.initLogging()

        DDLogInfo("Application starting in foreground ? \(UIApplication.shared.applicationState != .background)")
        ImageCache.default.memoryStorage.config.totalCostLimit = 20
        InfomaniakLogin.initWith(clientId: DriveApiFetcher.clientId)
        accountManager = AccountManager.instance
        uploadQueue = UploadQueue.instance
        reachabilityListener = ReachabilityListener.instance

        // Start audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            DDLogError("Error while setting playback audio category")
            SentrySDK.capture(error: error)
        }

        if #available(iOS 13.0, *) {
            registerBackgroundTasks()
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }

        NotificationsHelper.askForPermissions()
        NotificationsHelper.registerCategories()
        UNUserNotificationCenter.current().delegate = self

        if UIApplication.shared.applicationState != .background {
            launchSetup()
        }

        if CommandLine.arguments.contains("testing") {
            UIView.setAnimationsEnabled(false)
        }

        return true
    }

    @available(iOS 13.0, *)
    private func registerBackgroundTasks() {
        var registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Constants.backgroundRefreshIdentifier, using: nil) { (task) in
            self.scheduleBackgroundRefresh()

            task.expirationHandler = {
                UploadQueue.instance.suspendAllOperations()
                UploadQueue.instance.cancelRunningOperations()
                task.setTaskCompleted(success: false)
            }

            self.handleBackgroundRefresh { (newData) in
                task.setTaskCompleted(success: true)
            }
        }
        DDLogInfo("Task \(Constants.backgroundRefreshIdentifier) registered ? \(registered)")
        registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Constants.longBackgroundRefreshIdentifier, using: nil) { (task) in
            self.scheduleBackgroundRefresh()

            task.expirationHandler = {
                UploadQueue.instance.suspendAllOperations()
                UploadQueue.instance.cancelRunningOperations()
                task.setTaskCompleted(success: false)
            }

            self.handleBackgroundRefresh { (newData) in
                task.setTaskCompleted(success: true)
            }
        }
        DDLogInfo("Task \(Constants.longBackgroundRefreshIdentifier) registered ? \(registered)")
    }

    func handleBackgroundRefresh(completion: @escaping (Bool) -> Void) {
        //User installed the app but never logged in
        if accountManager.accounts.count == 0 {
            completion(false)
            return
        }

        let _ = PhotoLibraryUploader.instance.addNewPicturesToUploadQueue()
        UploadQueue.instance.waitForCompletion {
            completion(true)
        }
    }

    @available(iOS 13.0, *)
    private func scheduleBackgroundRefresh() {
        let backgroundRefreshRequest = BGAppRefreshTaskRequest(identifier: Constants.backgroundRefreshIdentifier)
        backgroundRefreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        let longBackgroundRefreshRequest = BGProcessingTaskRequest(identifier: Constants.longBackgroundRefreshIdentifier)
        longBackgroundRefreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        longBackgroundRefreshRequest.requiresNetworkConnectivity = true
        longBackgroundRefreshRequest.requiresExternalPower = true
        do {
            try BGTaskScheduler.shared.submit(backgroundRefreshRequest)
            try BGTaskScheduler.shared.submit(longBackgroundRefreshRequest)
        } catch {
            DDLogError("Error scheduling background task: \(error)")
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if #available(iOS 13.0, *) {
            /* To debug background tasks:
             Launch ->
             e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.infomaniak.background.refresh"]
             Force early termination ->
             e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.infomaniak.background.refresh"]
            */
            scheduleBackgroundRefresh()
        }
        if UserDefaults.shared.isAppLockEnabled && !(window?.rootViewController?.isKind(of: LockedAppViewController.self) ?? false) {
            AppLockHelper.shared.setTime()
        }
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        //Old Nextcloud based app only supports this way for background fetch so it's the only place it will be called in the background.
        if MigrationHelper.canMigrate() {
            NotificationsHelper.sendMigrateNotification()
            return
        }

        handleBackgroundRefresh { (newData) in
            if newData {
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.isFileURL, let currentDriveFileManager = accountManager.currentDriveFileManager {
            let filename = url.lastPathComponent
            let importPath = DriveFileManager.constants.importDirectoryURL.appendingPathComponent(filename)
            do {
                if FileManager.default.fileExists(atPath: importPath.path) {
                    try FileManager.default.removeItem(atPath: importPath.path)
                }
                try FileManager.default.moveItem(at: url, to: importPath)
                let saveNavigationViewController = SaveFileViewController.instantiateInNavigationController(driveFileManager: currentDriveFileManager, file: .init(name: filename, path: importPath, uti: importPath.typeIdentifier ?? .data))
                window?.rootViewController?.present(saveNavigationViewController, animated: true)
                return true
            } catch {
                return false
            }
        } else {
            return false
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        UploadQueue.instance.pausedNotificationSent = false
        launchSetup()
    }

    private func launchSetup() {
        // Set global tint color
        window?.tintColor = KDriveAsset.infomaniakColor.color
        UITabBar.appearance().unselectedItemTintColor = KDriveAsset.iconColor.color

        if MigrationHelper.canMigrate() {
            window?.rootViewController = MigrationViewController.instantiate()
            window?.makeKeyAndVisible()
        } else if (UserDefaults.isFirstLaunch() || accountManager.accounts.count == 0) {
            if !(window?.rootViewController?.isKind(of: OnboardingViewController.self) ?? false) {
                accountManager.deleteAllTokens()
                window?.rootViewController = OnboardingViewController.instantiate()
                window?.makeKeyAndVisible()
            }
        } else if UserDefaults.shared.isAppLockEnabled && AppLockHelper.shared.isAppLocked {
            window?.rootViewController = LockedAppViewController.instantiate()
            window?.makeKeyAndVisible()
        } else {
            UserDefaults.shared.numberOfConnections += 1
            var appVersion = AppVersion()
            appVersion.loadVersionData(handler: { [self] (version) in
                appVersion.version = version.version
                appVersion.currentVersionReleaseDate = version.currentVersionReleaseDate

                if appVersion.showUpdateFloatingPanel() {
                    if !UserDefaults.shared.updateLater || UserDefaults.shared.numberOfConnections % 10 == 0 {
                        let floatingPanelViewController = UpdateFloatingPanelViewController.instantiatePanel()
                        (floatingPanelViewController.contentViewController as? UpdateFloatingPanelViewController)?.actionHandler = {
                            sender in
                            if let url = URL(string: "https://apps.apple.com/app/infomaniak-kdrive/id1482778676") {
                                UserDefaults.shared.updateLater = false
                                UIApplication.shared.open(url)
                            }
                        }
                        self.window?.rootViewController?.present(floatingPanelViewController, animated: true)
                    }
                }
            })
            if let currentDriveFileManager = accountManager.currentDriveFileManager,
                UserDefaults.shared.numberOfConnections == 1 && !PhotoLibraryUploader.instance.isSyncEnabled {
                let floatingPanelViewController = SavePhotosFloatingPanelViewController.instantiatePanel()
                let savePhotosFloatingPanelViewController = (floatingPanelViewController.contentViewController as? SavePhotosFloatingPanelViewController)
                savePhotosFloatingPanelViewController?.driveFileManager = currentDriveFileManager
                savePhotosFloatingPanelViewController?.actionHandler = { [self] sender in
                    let photoSyncSettingsVC = PhotoSyncSettingsViewController.instantiate()
                    photoSyncSettingsVC.driveFileManager = currentDriveFileManager
                    let mainTabViewVC = self.window?.rootViewController as? UITabBarController
                    guard let currentVC = mainTabViewVC?.selectedViewController as? UINavigationController else {
                        return
                    }
                    currentVC.dismiss(animated: true)
                    currentVC.setInfomaniakAppearanceNavigationBar()
                    currentVC.pushViewController(photoSyncSettingsVC, animated: true)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.window?.rootViewController?.present(floatingPanelViewController, animated: true)
                }
            }
            /* TODO: uncomment when app will be ready for reviews
             if numberOfConnection == 10 {
                if #available(iOS 14.0, *) {
                    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                } else {
                    SKStoreReviewController.requestReview()
                }
            }
            */
            refreshCacheData(preload: false, isSwitching: false)
            uploadEditedFiles()
        }
    }

    func refreshCacheData(preload: Bool, isSwitching: Bool) {
        let currentAccount = AccountManager.instance.currentAccount!
        let rootViewController = self.window?.rootViewController as? SwitchAccountDelegate

        if preload {
            DispatchQueue.main.async {
                if isSwitching {
                    rootViewController?.didSwitchCurrentAccount(currentAccount)
                } else {
                    rootViewController?.didUpdateCurrentAccountInformations(currentAccount)
                }
            }
            updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
        } else {
            var token: ObservationToken?
            token = ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] (status) in
                updateAvailableOfflineFiles(status: status)
                // Remove observer after 1 pass
                token?.cancel()
            }
        }

        accountManager.updateUserForAccount(currentAccount) { (account, switchedDrive, error) in
            if let error = error {
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                DDLogError("Error while updating user account: \(error)")
            } else {
                if isSwitching {
                    rootViewController?.didSwitchCurrentAccount(currentAccount)
                } else {
                    rootViewController?.didUpdateCurrentAccountInformations(currentAccount)
                }
                if let drive = switchedDrive,
                    let driveFileManager = self.accountManager.getDriveFileManager(for: drive) {
                    (rootViewController as? SwitchDriveDelegate)?.didSwitchDriveFileManager(newDriveFileManager: driveFileManager)
                }
                UploadQueue.instance.resumeAllOperations()
                UploadQueue.instance.addToQueueFromRealm()
                BackgroundUploadSessionManager.instance.reconnectBackgroundTasks()
                DispatchQueue.global(qos: .utility).async {
                    let _ = PhotoLibraryUploader.instance.addNewPicturesToUploadQueue()
                }
            }
        }
    }

    private func uploadEditedFiles() {
        guard let folderURL = DriveFileManager.constants.openInPlaceDirectoryURL, FileManager.default.fileExists(atPath: folderURL.path) else { return }
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
                    let file = accountManager.getDriveFileManager(for: drive)?.getCachedFile(id: fileId) else {
                    DDLogInfo("[OPEN-IN-PLACE UPLOAD] Could not infer file from \(fileFolderURL)")
                    continue
                }
                let fileURL = fileFolderURL.appendingPathComponent(file.name)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    // Compare modification date
                    let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let modificationDate = attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
                    if modificationDate > file.lastModifiedDate {
                        // Copy and upload file
                        let uploadFile = UploadFile(parentDirectoryId: file.parentId,
                            userId: accountManager.currentUserId,
                            driveId: driveId,
                            url: fileURL,
                            name: file.name,
                            shouldRemoveAfterUpload: false)
                        uploadQueue.addToQueue(file: uploadFile)
                        group.enter()
                        shouldCleanFolder = true
                        uploadQueue.observeFileUploaded(self, fileId: uploadFile.id) { (uploadFile, _) in
                            if let error = uploadFile.error {
                                shouldCleanFolder = false
                                DDLogError("[OPEN-IN-PLACE UPLOAD] Error while uploading: \(error)")
                            }
                            group.leave()
                        }
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

    private func updateAvailableOfflineFiles(status: ReachabilityListener.NetworkStatus) {
        guard status != .offline && (!UserDefaults.shared.isWifiOnly || status == .wifi) else {
            return
        }

        let drives = DriveInfosManager.instance.getDrives(for: accountManager.currentUserId, sharedWithMe: false)
        for drive in drives {
            guard let driveFileManager = accountManager.getDriveFileManager(for: drive) else {
                continue
            }

            let offlineFiles = driveFileManager.getAvailableOfflineFiles()
            for file in offlineFiles {
                driveFileManager.getFile(id: file.id, withExtras: true) { (newFile, _, error) in
                    if let error = error {
                        if let error = error as? DriveError, error == .objectNotFound {
                            driveFileManager.setFileAvailableOffline(file: file, available: false) { (error) in }
                        } else {
                            SentrySDK.capture(error: error)
                        }
                        // Silently handle error
                        DDLogError("Error while fetching [\(file.id) - \(file.name)] in [\(drive.id) - \(drive.name)]: \(error)")
                    } else if let newFile = newFile {
                        try? driveFileManager.renameCachedFile(updatedFile: newFile, oldFile: file)
                        if newFile.isLocalVersionOlderThanRemote() {
                            // Download new version
                            DownloadQueue.instance.addToQueue(file: newFile, userId: driveFileManager.drive.userId)
                        }
                    }
                }
            }
        }
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == DownloadQueue.backgroundIdentifier {
            BackgroundDownloadSessionManager.instance.backgroundCompletionHandler = completionHandler
        } else if identifier == UploadQueue.backgroundIdentifier {
            BackgroundUploadSessionManager.instance.backgroundCompletionHandler = completionHandler
        } else {
            completionHandler()
        }
    }

    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return InfomaniakLogin.handleRedirectUri(url: url)
    }

    func setRootViewController(_ vc: UIViewController, animated: Bool = true) {
        guard animated, let window = self.window else {
            self.window?.rootViewController = vc
            self.window?.makeKeyAndVisible()
            return
        }

        window.rootViewController = vc
        window.makeKeyAndVisible()
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: nil)
    }

    // MARK: - Account manager delegate

    func currentAccountNeedsAuthentication() {
        setRootViewController(SwitchUserViewController.instantiateInNavigationController())
        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorDisconnected)
    }

    // MARK: - User notification center delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if response.notification.request.content.categoryIdentifier == NotificationsHelper.uploadCategoryId {
            // Upload notification
            let parentId = userInfo[NotificationsHelper.parentIdKey] as? Int

            switch response.actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                // Notification tapped: open parent folder
                guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController as? MainTabViewController else {
                    completionHandler()
                    return
                }
                // Dismiss all view controllers presented
                rootViewController.dismiss(animated: false)
                // Select Files tab
                rootViewController.selectedIndex = 1

                if let navController = rootViewController.selectedViewController as? UINavigationController {
                    // Pop to root
                    navController.popToRootViewController(animated: false)
                    // Present folder (if it's not root)
                    if let parentId = parentId, parentId > DriveFileManager.constants.rootID, let directory = accountManager.currentDriveFileManager?.getCachedFile(id: parentId) {
                        let filesList = FileListCollectionViewController.instantiate()
                        filesList.currentDirectory = directory
                        navController.pushViewController(filesList, animated: false)
                    }
                }
            default:
                break
            }
        }
        else {
            // Handle other notification types...
        }

        completionHandler()
    }
}
