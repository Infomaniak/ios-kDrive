/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import InfomaniakCore
import InfomaniakCoreUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import SafariServices
import UIKit
import VersionChecker

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    @LazyInjectService var lockHelper: AppLockHelper
    @LazyInjectService var backgroundUploadSessionManager: BackgroundUploadSessionManager
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager
    @LazyInjectService var keychainHelper: KeychainHelper
    @LazyInjectService var backgroundTasksService: BackgroundTasksServiceable
    @LazyInjectService var reviewManager: ReviewManageable
    @LazyInjectService var availableOfflineManager: AvailableOfflineManageable

    // TODO: Fixme
    private var shortcutItemToProcess: UIApplicationShortcutItem?

    var window: UIWindow?

    /** Apps configure their UIWindow and attach it to the provided UIWindowScene scene.
         The system calls willConnectTo shortly after the app delegate's "configurationForConnecting" function.
         Use this function to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.

         When using a storyboard file, as specified by the Info.plist key, UISceneStoryboardFile, the system automatically configures
         the window property and attaches it to the windowScene.

         Remember to retain the SceneDelegate's UIWindow.
         The recommended approach is for the SceneDelegate to retain the scene's window.
     */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print(" scene session options")
        /// 1. Capture the scene
        guard let windowScene = (scene as? UIWindowScene) else { return }

        /// 2. Create a new UIWindow using the windowScene constructor which takes in a window scene.
        let window = UIWindow(windowScene: windowScene)

        /// 3. Create a view hierarchy programmatically
//        let viewController = ArticleListViewController()
//        let navigation = UINavigationController(rootViewController: viewController)

        /// 4. Set the root view controller of the window with your view controller
//        window.rootViewController = navigation

        /// 5. Set the window and call makeKeyAndVisible()
        self.window = window
        window.makeKeyAndVisible()
    }

    func configure(window: UIWindow?, session: UISceneSession, with activity: NSUserActivity) -> Bool {
        print(" configure session with")
        return true
    }

    /** Use this delegate as the system is releasing the scene or on window close.
         This occurs shortly after the scene enters the background, or when the system discards its session.
         Release any scene-related resources that the system can recreate the next time the scene connects.
         The scene may reconnect later because the system didn't necessarily discard its session (see`application:didDiscardSceneSessions` instead),
         so don't delete any user data or state permanently.
     */
    func sceneDidDisconnect(_ scene: UIScene) {
        print(" sceneDidDisconnect \(scene)")
    }

    /** Use this delegate when the scene moves from an active state to an inactive state, on window close, or in iOS enter background.
         This may occur due to temporary interruptions (for example, an incoming phone call).
     */
    func sceneWillResignActive(_ scene: UIScene) {
        print(" sceneWillResignActive \(scene)")
    }

    /** Use this delegate as the scene transitions from the background to the foreground, on window open, or in iOS resume.
         Use it to undo the changes made on entering the background.
     */
    func sceneWillEnterForeground(_ scene: UIScene) {
        print(" sceneWillEnterForeground \(scene) \(window)")
        @InjectService var uploadQueue: UploadQueue
        uploadQueue.pausedNotificationSent = false

        let currentState = RootViewControllerState.getCurrentState()
        prepareRootViewController(currentState: currentState)
        switch currentState {
        case .mainViewController, .appLock:
            UserDefaults.shared.numberOfConnections += 1
            UserDefaults.shared.openingUntilReview -= 1
            refreshCacheScanLibraryAndUpload(preload: false, isSwitching: false)
            uploadEditedFiles()
        case .onboarding, .updateRequired, .preloading: break
        }

        // Remove all notifications on App Opening
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        Task {
            if try await VersionChecker.standard.checkAppVersionStatus() == .updateIsRequired {
                prepareRootViewController(currentState: .updateRequired)
            }
        }
    }

    /** Use this delegate when the scene "has moved" from an inactive state to an active state.
         Also use it to restart any tasks that the system paused (or didn't start) when the scene was inactive.
         The system calls this delegate every time a scene becomes active so set up your scene UI here.
     */
    func sceneDidBecomeActive(_ scene: UIScene) {
        print(" sceneDidBecomeActive \(scene)")
        if let shortcutItem = shortcutItemToProcess {
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

    /** Use this delegate as the scene transitions from the foreground to the background.
        Also use it to save data, release shared resources, and store enough scene-specific state information
        to restore the scene to its current state.
     */
    func sceneDidEnterBackground(_ scene: UIScene) {
        print(" sceneDidEnterBackground \(scene)")
        backgroundTasksService.scheduleBackgroundRefresh()

        if UserDefaults.shared.isAppLockEnabled,
           !(window?.rootViewController?.isKind(of: LockedAppViewController.self) ?? false) {
            lockHelper.setTime()
        }
    }

    // MARK: - Window Scene

    // Listen for size change.
    func windowScene(_ windowScene: UIWindowScene,
                     didUpdate previousCoordinateSpace: UICoordinateSpace,
                     interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                     traitCollection previousTraitCollection: UITraitCollection) {
        print(" windowScene didUpdate")
    }

    // MARK: - Handoff support

    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
        print(" scene willContinueUserActivityWithType")
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print(" scene continue userActivity")
    }

    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        print(" scene didFailToContinueUserActivityWithType")
    }
}

// TODO: Refactor with router like pattern and split code away from this class
extension SceneDelegate {
    func refreshCacheScanLibraryAndUpload(preload: Bool, isSwitching: Bool) {
        Log.appDelegate("refreshCacheScanLibraryAndUpload preload:\(preload) isSwitching:\(preload)")

        guard let currentAccount = accountManager.currentAccount else {
            Log.appDelegate("No account to refresh", level: .error)
            return
        }

        let rootViewController = window?.rootViewController as? UpdateAccountDelegate

        availableOfflineManager.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)

        Task {
            do {
                let oldDriveId = accountManager.currentDriveFileManager?.drive.objectId
                let account = try await accountManager.updateUser(for: currentAccount, registerToken: true)
                rootViewController?.didUpdateCurrentAccountInformations(account)

                if let oldDriveId,
                   let newDrive = driveInfosManager.getDrive(primaryKey: oldDriveId),
                   !newDrive.inMaintenance {
                    // The current drive is still usable, do not switch
                    scanLibraryAndRestartUpload()
                    return
                }

                let driveFileManager = try accountManager.getFirstAvailableDriveFileManager(for: account.userId)
                accountManager.setCurrentDriveForCurrentAccount(drive: driveFileManager.drive)
                showMainViewController(driveFileManager: driveFileManager)
                scanLibraryAndRestartUpload()
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

    func prepareRootViewController(currentState: RootViewControllerState) {
        print(" prepareRootViewController:\(currentState)")
        switch currentState {
        case .appLock:
            showAppLock()
        case .mainViewController(let driveFileManager):
            showMainViewController(driveFileManager: driveFileManager)
            showLaunchFloatingPanel()
            askForReview()
            askUserToRemovePicturesIfNecessary()
        case .onboarding:
            showOnboarding()
        case .updateRequired:
            showUpdateRequired()
        case .preloading(let currentAccount):
            showPreloading(currentAccount: currentAccount)
        }
    }

    func uploadEditedFiles() {
        Log.appDelegate("uploadEditedFiles")
        guard let folderURL = DriveFileManager.constants.openInPlaceDirectoryURL,
              FileManager.default.fileExists(atPath: folderURL.path) else {
            return
        }

        let group = DispatchGroup()
        var shouldCleanFolder = false
        let driveFolders = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)) ?? []
        // Hierarchy inside folderURL should be /driveId/fileId/fileName.extension
        for driveFolder in driveFolders {
            // Read drive folder
            let driveFolderURL = folderURL.appendingPathComponent(driveFolder)
            guard let driveId = Int(driveFolder),
                  let drive = driveInfosManager.getDrive(id: driveId, userId: accountManager.currentUserId),
                  let fileFolders = try? FileManager.default.contentsOfDirectory(atPath: driveFolderURL.path) else {
                Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer drive from \(driveFolderURL)")
                continue
            }

            for fileFolder in fileFolders {
                // Read file folder
                let fileFolderURL = driveFolderURL.appendingPathComponent(fileFolder)
                guard let fileId = Int(fileFolder),
                      let driveFileManager = accountManager.getDriveFileManager(for: drive),
                      let file = driveFileManager.getCachedFile(id: fileId) else {
                    Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Could not infer file from \(fileFolderURL)")
                    continue
                }

                let fileURL = fileFolderURL.appendingPathComponent(file.name)
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continue
                }

                // Compare modification date
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)

                guard modificationDate > file.lastModifiedAt else {
                    continue
                }

                // Copy and upload file
                let uploadFile = UploadFile(parentDirectoryId: file.parentId,
                                            userId: accountManager.currentUserId,
                                            driveId: file.driveId,
                                            url: fileURL,
                                            name: file.name,
                                            conflictOption: .version,
                                            shouldRemoveAfterUpload: false)
                group.enter()
                shouldCleanFolder = true
                @InjectService var uploadQueue: UploadQueue
                var observationToken: ObservationToken?
                observationToken = uploadQueue
                    .observeFileUploaded(self, fileId: uploadFile.id) { [fileId = file.id] uploadFile, _ in
                        observationToken?.cancel()
                        if let error = uploadFile.error {
                            shouldCleanFolder = false
                            Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Error while uploading: \(error)", level: .error)
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
                uploadQueue.saveToRealm(uploadFile, itemIdentifier: nil)
            }
        }

        // Clean folder after completing all uploads
        group.notify(queue: DispatchQueue.global(qos: .utility)) {
            if shouldCleanFolder {
                Log.appDelegate("[OPEN-IN-PLACE UPLOAD] Cleaning folder")
                try? FileManager.default.removeItem(at: folderURL)
            }
        }
    }

    // MARK: Actions

    private func askForReview() {
        guard let presentingViewController = window?.rootViewController,
              !Bundle.main.isRunningInTestFlight
        else { return }

        let shouldRequestReview = reviewManager.shouldRequestReview()

        if shouldRequestReview {
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
            let alert = AlertTextViewController(
                title: appName,
                message: KDriveResourcesStrings.Localizable.reviewAlertTitle,
                action: KDriveResourcesStrings.Localizable.buttonYes,
                hasCancelButton: true,
                cancelString: KDriveResourcesStrings.Localizable.buttonNo,
                handler: requestAppStoreReview,
                cancelHandler: openUserReport
            )

            presentingViewController.present(alert, animated: true)
            MatomoUtils.track(eventWithCategory: .appReview, name: "alertPresented")
        }
    }

    private func requestAppStoreReview() {
        MatomoUtils.track(eventWithCategory: .appReview, name: "like")
        UserDefaults.shared.appReview = .readyForReview
        reviewManager.requestReview()
    }

    private func openUserReport() {
        MatomoUtils.track(eventWithCategory: .appReview, name: "dislike")
        guard let url = URL(string: KDriveResourcesStrings.Localizable.urlUserReportiOS),
              let presentingViewController = window?.rootViewController else {
            return
        }
        UserDefaults.shared.appReview = .feedback
        presentingViewController.present(SFSafariViewController(url: url), animated: true)
    }

    /// Ask the user to remove pictures if configured
    private func askUserToRemovePicturesIfNecessary() {
        @InjectService var photoCleaner: PhotoLibraryCleanerServiceable
        guard photoCleaner.hasPicturesToRemove else {
            Log.appDelegate("No pictures to remove", level: .info)
            return
        }

        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalDeletePhotosTitle,
                                            message: KDriveResourcesStrings.Localizable.modalDeletePhotosDescription,
                                            action: KDriveResourcesStrings.Localizable.buttonDelete,
                                            destructive: true,
                                            loading: false) {
            Task {
                // Proceed with removal
                await photoCleaner.removePicturesScheduledForDeletion()
            }
        }

        Task { @MainActor in
            self.window?.rootViewController?.present(alert, animated: true)
        }
    }

    // MARK: Photo library

    private func scanLibraryAndRestartUpload() {
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

    // MARK: Show

    func setRootViewController(_ vc: UIViewController,
                               animated: Bool = true) {
        guard let window else {
            return
        }

        window.rootViewController = vc
        window.makeKeyAndVisible()

        guard animated else {
            return
        }

        UIView.transition(with: window, duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil,
                          completion: nil)
    }

    func showMainViewController(driveFileManager: DriveFileManager) {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        let currentDriveObjectId = (window.rootViewController as? MainTabViewController)?.driveFileManager.drive.objectId
        guard currentDriveObjectId != driveFileManager.drive.objectId else {
            return
        }

        window.rootViewController = MainTabViewController(driveFileManager: driveFileManager)
        window.makeKeyAndVisible()
    }

    func showPreloading(currentAccount: Account) {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = PreloadingViewController(currentAccount: currentAccount)
        window.makeKeyAndVisible()
    }

    private func showOnboarding() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        defer {
            // Clean File Provider domains on first launch in case we had some dangling
            driveInfosManager.deleteAllFileProviderDomains()
        }

        // Check if presenting onboarding
        let isNotPresentingOnboarding = window.rootViewController?.isKind(of: OnboardingViewController.self) != true
        guard isNotPresentingOnboarding else {
            return
        }

        keychainHelper.deleteAllTokens()
        window.rootViewController = OnboardingViewController.instantiate()
        window.makeKeyAndVisible()
    }

    private func showAppLock() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = LockedAppViewController.instantiate()
        window.makeKeyAndVisible()
    }

    private func showLaunchFloatingPanel() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        let launchPanelsController = LaunchPanelsController()
        if let viewController = window.rootViewController {
            launchPanelsController.pickAndDisplayPanel(viewController: viewController)
        }
    }

    private func showUpdateRequired() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = DriveUpdateRequiredViewController()
        window.makeKeyAndVisible()
    }
}
