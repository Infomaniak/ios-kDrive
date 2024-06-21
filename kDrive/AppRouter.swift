/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

/// Something that can navigate to specific places of the kDrive app
public protocol RouterAppNavigable {
    /// Show the main view with a customizable selected index
    /// - Parameters:
    ///   - driveFileManager: driveFileManager to use
    ///   - selectedIndex: Nil will try to use state restoration if available
    @MainActor func showMainViewController(driveFileManager: DriveFileManager, selectedIndex: Int?) -> UITabBarController?

    @MainActor func showPreloading(currentAccount: Account)

    @MainActor func showOnboarding()

    @MainActor func showAppLock()

    @MainActor func showLaunchFloatingPanel()

    @MainActor func showUpdateRequired()

    @MainActor func showPhotoSyncSettings()
}

/// Something that can present a File within the app
public protocol RouterFileNavigable {
    /// Pop to root and present file, will never open OnlyOffice
    /// - Parameters:
    ///   - file: File to display
    ///   - driveFileManager: driveFileManager
    @MainActor func present(file: File, driveFileManager: DriveFileManager)

    /// Pop to root and present file
    /// - Parameters:
    ///   - file: File to display
    ///   - driveFileManager: driveFileManager
    ///   - office: Open in only office
    @MainActor func present(file: File, driveFileManager: DriveFileManager, office: Bool)

    /// Present a list of files from a folder
    /// - Parameters:
    ///   - frozenFolder: Folder to display
    ///   - driveFileManager: driveFileManager
    ///   - navigationController: The navigation controller to use
    @MainActor func presentFileList(
        frozenFolder: File,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController
    )

    /// Present PreviewViewController
    /// - Parameters:
    ///   - frozenFiles: File list to display, must be frozen
    ///   - index: The Index of the file to display
    ///   - driveFileManager: The driveFileManager
    ///   - normalFolderHierarchy: See FileListViewModel.Configuration for details
    ///   - fromActivities: Opening from an activity
    ///   - navigationController: The navigation controller to use
    ///   - animated: Should be animated
    @MainActor func presentPreviewViewController(
        frozenFiles: [File],
        index: Int,
        driveFileManager: DriveFileManager,
        normalFolderHierarchy: Bool,
        fromActivities: Bool,
        navigationController: UINavigationController,
        animated: Bool
    )

    /// Present the details of a file and all the linked metadata
    /// - Parameters:
    ///   - frozenFile: A frozen file to display
    ///   - driveFileManager: driveFileManager
    ///   - navigationController: The navigation controller to use
    ///   - animated: Should be animated
    @MainActor func presentFileDetails(
        frozenFile: File,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    )

    /// Present the InApp purchase StoreViewController
    /// - Parameters:
    ///   - driveFileManager: driveFileManager
    ///   - navigationController: The navigation controller to use
    ///   - animated: Should be animated
    @MainActor func presentStoreViewController(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    )
}

/// Something that can set an arbitrary RootView controller
public protocol RouterRootNavigable {
    /// Something that can set an arbitrary RootView controller
    ///
    /// Should not be used externally except by SceneDelegate.
    @MainActor func setRootViewController(_ viewController: UIViewController,
                                          animated: Bool)

    /// Setup the root of the view stack
    /// - Parameters:
    ///   - currentState: the state to present
    ///   - restoration: try to restore scene or not
    @MainActor func prepareRootViewController(currentState: RootViewControllerState, restoration: Bool)

    /// Set the main theme color
    @MainActor func updateTheme()
}

public protocol TopmostViewControllerFetchable {
    /// Access the current top most ViewController
    @MainActor var topMostViewController: UIViewController? { get }
}

/// Actions performed by router, `async` by design
public protocol RouterActionable {
    /// Ask the user to review the app
    func askForReview() async

    /// Ask the user to remove pictures if configured
    func askUserToRemovePicturesIfNecessary() async

    func refreshCacheScanLibraryAndUpload(preload: Bool, isSwitching: Bool) async
}

/// Something that can navigate within the kDrive app
public typealias AppNavigable = RouterActionable
    & RouterAppNavigable
    & RouterFileNavigable
    & RouterRootNavigable
    & TopmostViewControllerFetchable

public struct AppRouter: AppNavigable {
    @LazyInjectService private var driveInfosManager: DriveInfosManager
    @LazyInjectService private var keychainHelper: KeychainHelper
    @LazyInjectService private var reviewManager: ReviewManageable
    @LazyInjectService private var availableOfflineManager: AvailableOfflineManageable
    @LazyInjectService private var backgroundUploadSessionManager: BackgroundUploadSessionManager
    @LazyInjectService private var accountManager: AccountManageable

    /// Get the current window from the app scene
    @MainActor private var window: UIWindow? {
        let scene = UIApplication.shared.connectedScenes.first { scene in
            guard let delegate = scene.delegate,
                  delegate as? SceneDelegate != nil else {
                return false
            }

            return true
        }

        guard let sceneDelegate = scene?.delegate as? SceneDelegate,
              let window = sceneDelegate.window else {
            return nil
        }

        return window
    }

    @MainActor var sceneUserInfo: [AnyHashable: Any]? {
        guard let scene = window?.windowScene,
              let userInfo = scene.userActivity?.userInfo else {
            return nil
        }

        return userInfo
    }

    // MARK: TopmostViewControllerFetchable

    @MainActor public var topMostViewController: UIViewController? {
        var topViewController = window?.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }

    // MARK: RouterRootNavigable

    @MainActor public func setRootViewController(_ viewController: UIViewController,
                                                 animated: Bool) {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        guard animated else {
            return
        }

        UIView.transition(with: window, duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil,
                          completion: nil)
    }

    @MainActor public func prepareRootViewController(currentState: RootViewControllerState, restoration: Bool) {
        switch currentState {
        case .appLock:
            showAppLock()
        case .mainViewController(let driveFileManager):

            restoreMainUIStackIfPossible(driveFileManager: driveFileManager, restoration: restoration)

            showLaunchFloatingPanel()
            Task {
                await askForReview()
                await askUserToRemovePicturesIfNecessary()
            }
        case .onboarding:
            showOnboarding()
        case .updateRequired:
            showUpdateRequired()
        case .preloading(let currentAccount):
            showPreloading(currentAccount: currentAccount)
        }
    }

    /// Entry point for scene restoration
    @MainActor func restoreMainUIStackIfPossible(driveFileManager: DriveFileManager, restoration: Bool) {
        var indexToUse: Int?
        if let sceneUserInfo,
           let index = sceneUserInfo[SceneRestorationKeys.selectedIndex.rawValue] as? Int {
            indexToUse = index
        }

        let tabBarViewController = showMainViewController(driveFileManager: driveFileManager, selectedIndex: indexToUse)

        guard restoration, let tabBarViewController else {
            return
        }

        Task { @MainActor in
            guard let sceneUserInfo,
                  let lastViewControllerString = sceneUserInfo[SceneRestorationKeys.lastViewController.rawValue] as? String,
                  let lastViewController = SceneRestorationScreens(rawValue: lastViewControllerString) else {
                return
            }

            let selectedIndex = tabBarViewController.selectedIndex
            let viewControllers = tabBarViewController.viewControllers
            guard let rootNavigationController = viewControllers?[safe: selectedIndex] as? UINavigationController else {
                Log.sceneDelegate("unable to access navigationController", level: .error)
                return
            }

            switch lastViewController {
            case .FileDetailViewController:
                await restoreFileDetailViewController(
                    driveFileManager: driveFileManager,
                    navigationController: rootNavigationController,
                    sceneUserInfo: sceneUserInfo
                )

            case .FileListViewController:
                await restoreFileListViewController(
                    driveFileManager: driveFileManager,
                    navigationController: rootNavigationController,
                    sceneUserInfo: sceneUserInfo
                )

            case .PreviewViewController:
                await restorePreviewViewController(
                    driveFileManager: driveFileManager,
                    navigationController: rootNavigationController,
                    sceneUserInfo: sceneUserInfo
                )

            case .StoreViewController:
                await restoreStoreViewController(
                    driveFileManager: driveFileManager,
                    navigationController: rootNavigationController,
                    sceneUserInfo: sceneUserInfo
                )
            }
        }
    }

    private func restoreFileDetailViewController(driveFileManager: DriveFileManager,
                                                 navigationController: UINavigationController,
                                                 sceneUserInfo: [AnyHashable: Any]) async {
        guard let fileId = sceneUserInfo[SceneRestorationValues.fileId.rawValue] else {
            Log.sceneDelegate("unable to load file id", level: .error)
            return
        }

        let database = driveFileManager.database
        let frozenFile = database.fetchObject(ofType: File.self) { partial in
            partial
                .filter("id == %@", fileId)
                .first?
                .freezeIfNeeded()
        }

        guard let frozenFile else {
            Log.sceneDelegate("unable to load file", level: .error)
            return
        }

        await presentFileDetails(frozenFile: frozenFile,
                                 driveFileManager: driveFileManager,
                                 navigationController: navigationController,
                                 animated: false)
    }

    private func restoreFileListViewController(driveFileManager: DriveFileManager,
                                               navigationController: UINavigationController,
                                               sceneUserInfo: [AnyHashable: Any]) async {
        guard let driveId = sceneUserInfo[SceneRestorationValues.driveId.rawValue] as? Int,
              driveFileManager.drive.id == driveId,
              let fileId = sceneUserInfo[SceneRestorationValues.fileId.rawValue] else {
            Log.sceneDelegate("metadata issue for FileList :\(sceneUserInfo)", level: .error)
            return
        }

        let database = driveFileManager.database
        let frozenFile = database.fetchObject(ofType: File.self) { partial in
            partial
                .filter("id == %@", fileId)
                .first?
                .freezeIfNeeded()
        }

        guard let frozenFile else {
            Log.sceneDelegate("unable to load file", level: .error)
            return
        }

        await presentFileList(frozenFolder: frozenFile,
                              driveFileManager: driveFileManager,
                              navigationController: navigationController)
    }

    private func restorePreviewViewController(driveFileManager: DriveFileManager,
                                              navigationController: UINavigationController,
                                              sceneUserInfo: [AnyHashable: Any]) async {
        guard let driveId = sceneUserInfo[SceneRestorationValues.driveId.rawValue] as? Int,
              let fileIds = sceneUserInfo[SceneRestorationValues.Carousel.filesIds.rawValue] as? [Int],
              let currentIndex = sceneUserInfo[SceneRestorationValues.Carousel.currentIndex.rawValue] as? Int,
              let normalFolderHierarchy = sceneUserInfo[SceneRestorationValues.Carousel.normalFolderHierarchy.rawValue] as? Bool,
              let fromActivities = sceneUserInfo[SceneRestorationValues.Carousel.fromActivities.rawValue] as? Bool else {
            Log.sceneDelegate("metadata issue for PreviewController :\(sceneUserInfo)", level: .error)
            return
        }

        let database = driveFileManager.database
        let frozenFetchedFiles = database.fetchResults(ofType: File.self) { partial in
            partial
                .filter("id IN %@", fileIds)
                .freezeIfNeeded()
        }

        let frozenFilesToRestore = Array(frozenFetchedFiles)

        await presentPreviewViewController(
            frozenFiles: frozenFilesToRestore,
            index: currentIndex,
            driveFileManager: driveFileManager,
            normalFolderHierarchy: normalFolderHierarchy,
            fromActivities: fromActivities,
            navigationController: navigationController,
            animated: false
        )
    }

    private func restoreStoreViewController(driveFileManager: DriveFileManager,
                                            navigationController: UINavigationController,
                                            sceneUserInfo: [AnyHashable: Any]) async {
        guard let driveId = sceneUserInfo[SceneRestorationValues.driveId.rawValue] as? Int,
              driveFileManager.drive.id == driveId else {
            Log.sceneDelegate("unable to load drive id", level: .error)
            return
        }

        await presentStoreViewController(
            driveFileManager: driveFileManager,
            navigationController: navigationController,
            animated: false
        )
    }

    @MainActor public func updateTheme() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.overrideUserInterfaceStyle = UserDefaults.shared.theme.interfaceStyle
    }

    // MARK: RouterAppNavigable

    @discardableResult
    @MainActor public func showMainViewController(driveFileManager: DriveFileManager,
                                                  selectedIndex: Int?) -> UITabBarController? {
        guard let window else {
            SentryDebug.captureNoWindow()
            return nil
        }

        let currentDriveObjectId = (window.rootViewController as? MainTabViewController)?.driveFileManager.drive.objectId
        guard currentDriveObjectId != driveFileManager.drive.objectId else {
            return nil
        }

        let tabBarViewController = MainTabViewController(driveFileManager: driveFileManager,
                                                         selectedIndex: selectedIndex)

        window.rootViewController = tabBarViewController
        window.makeKeyAndVisible()

        return tabBarViewController
    }

    @MainActor public func showPreloading(currentAccount: Account) {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = PreloadingViewController(currentAccount: currentAccount)
        window.makeKeyAndVisible()
    }

    @MainActor public func showOnboarding() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        defer {
            // Clean File Provider domains on first launch in case we had some dangling
            driveInfosManager.deleteAllFileProviderDomains()
        }

        let isNotPresentingOnboarding = window.rootViewController?.isKind(of: OnboardingViewController.self) != true
        guard isNotPresentingOnboarding else {
            return
        }

        keychainHelper.deleteAllTokens()
        window.rootViewController = OnboardingViewController.instantiate()
        window.makeKeyAndVisible()
    }

    @MainActor public func showAppLock() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = LockedAppViewController.instantiate()
        window.makeKeyAndVisible()
    }

    @MainActor public func showLaunchFloatingPanel() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        let launchPanelsController = LaunchPanelsController()
        if let viewController = window.rootViewController {
            launchPanelsController.pickAndDisplayPanel(viewController: viewController)
        }
    }

    @MainActor public func showUpdateRequired() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = DriveUpdateRequiredViewController()
        window.makeKeyAndVisible()
    }

    @MainActor public func showPhotoSyncSettings() {
        guard let rootViewController = window?.rootViewController as? MainTabViewController else {
            return
        }

        rootViewController.dismiss(animated: false)
        rootViewController.selectedIndex = MainTabIndex.profile.rawValue

        guard let navController = rootViewController.selectedViewController as? UINavigationController else {
            return
        }

        let photoSyncSettingsViewController = PhotoSyncSettingsViewController.instantiate()
        navController.popToRootViewController(animated: false)
        navController.pushViewController(photoSyncSettingsViewController, animated: true)
    }

    // MARK: RouterActionable

    public func askUserToRemovePicturesIfNecessary() async {
        @InjectService var photoCleaner: PhotoLibraryCleanerServiceable
        guard photoCleaner.hasPicturesToRemove else {
            Log.sceneDelegate("No pictures to remove", level: .info)
            return
        }

        Task { @MainActor in
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalDeletePhotosTitle,
                                                message: KDriveResourcesStrings.Localizable.modalDeletePhotosDescription,
                                                action: KDriveResourcesStrings.Localizable.buttonDelete,
                                                destructive: true,
                                                loading: false) {
                Task {
                    @InjectService var photoCleaner: PhotoLibraryCleanerServiceable
                    await photoCleaner.removePicturesScheduledForDeletion()
                }
            }

            window?.rootViewController?.present(alert, animated: true)
        }
    }

    public func askForReview() async {
        guard let presentingViewController = await window?.rootViewController,
              !Bundle.main.isRunningInTestFlight else {
            return
        }

        guard reviewManager.shouldRequestReview() else {
            return
        }

        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String

        Task { @MainActor in
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
        }
        MatomoUtils.track(eventWithCategory: .appReview, name: "alertPresented")
    }

    @MainActor private func requestAppStoreReview() {
        MatomoUtils.track(eventWithCategory: .appReview, name: "like")
        UserDefaults.shared.appReview = .readyForReview
        reviewManager.requestReview()
    }

    @MainActor private func openUserReport() {
        MatomoUtils.track(eventWithCategory: .appReview, name: "dislike")
        guard let url = URL(string: KDriveResourcesStrings.Localizable.urlUserReportiOS),
              let presentingViewController = window?.rootViewController else {
            return
        }
        UserDefaults.shared.appReview = .feedback
        presentingViewController.present(SFSafariViewController(url: url), animated: true)
    }

    public func refreshCacheScanLibraryAndUpload(preload: Bool, isSwitching: Bool) async {
        Log.sceneDelegate("refreshCacheScanLibraryAndUpload preload:\(preload) isSwitching:\(preload)")

        availableOfflineManager.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)

        do {
            try await refreshAccountAndShowMainView()
            await scanLibraryAndRestartUpload()
        } catch DriveError.NoDriveError.noDrive {
            let driveErrorNavigationViewController = await DriveErrorViewController.instantiateInNavigationController(
                errorType: .noDrive,
                drive: nil
            )
            await setRootViewController(driveErrorNavigationViewController, animated: true)
        } catch DriveError.NoDriveError.blocked(let drive), DriveError.NoDriveError.maintenance(let drive) {
            let driveErrorNavigationViewController = await DriveErrorViewController.instantiateInNavigationController(
                errorType: drive.isInTechnicalMaintenance ? .maintenance : .blocked,
                drive: drive
            )
            await setRootViewController(driveErrorNavigationViewController, animated: true)
        } catch {
            await UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
            Log.sceneDelegate("Error while updating user account: \(error)", level: .error)
        }
    }

    @MainActor private func refreshAccountAndShowMainView() async throws {
        let oldDriveId = accountManager.currentDriveFileManager?.drive.objectId

        guard let currentAccount = accountManager.currentAccount else {
            Log.sceneDelegate("No account to refresh", level: .error)
            return
        }

        let account = try await accountManager.updateUser(for: currentAccount, registerToken: true)
        let rootViewController = window?.rootViewController as? UpdateAccountDelegate
        rootViewController?.didUpdateCurrentAccountInformations(account)

        if let oldDriveId,
           let newDrive = driveInfosManager.getDrive(primaryKey: oldDriveId),
           !newDrive.inMaintenance {
            // The current drive is still usable, do not switch
            await scanLibraryAndRestartUpload()
            return
        }

        let driveFileManager = try accountManager.getFirstAvailableDriveFileManager(for: account.userId)
        let drive = driveFileManager.drive
        accountManager.setCurrentDriveForCurrentAccount(for: drive.id, userId: drive.userId)
        showMainViewController(driveFileManager: driveFileManager, selectedIndex: nil)
    }

    private func scanLibraryAndRestartUpload() async {
        backgroundUploadSessionManager.reconnectBackgroundTasks()

        Log.sceneDelegate("Restart queue")
        @InjectService var photoUploader: PhotoLibraryUploader
        photoUploader.scheduleNewPicturesForUpload()

        // Resolving an upload queue will restart it if this is the first time
        @InjectService var uploadQueue: UploadQueue
        uploadQueue.rebuildUploadQueueFromObjectsInRealm()
    }

    // MARK: RouterFileNavigable

    @MainActor public func present(file: File, driveFileManager: DriveFileManager) {
        present(file: file, driveFileManager: driveFileManager, office: false)
    }

    @MainActor public func present(file: File, driveFileManager: DriveFileManager, office: Bool) {
        guard let rootViewController = window?.rootViewController as? MainTabViewController else {
            return
        }

        rootViewController.dismiss(animated: false) {
            rootViewController.selectedIndex = MainTabIndex.files.rawValue

            guard let navController = rootViewController.selectedViewController as? UINavigationController,
                  let viewController = navController.topViewController as? FileListViewController else {
                return
            }

            guard !file.isRoot && viewController.viewModel.currentDirectory.id != file.id else {
                return
            }

            navController.popToRootViewController(animated: false)

            guard let fileListViewController = navController.topViewController as? FileListViewController else {
                return
            }

            if office {
                OnlyOfficeViewController.open(driveFileManager: driveFileManager,
                                              file: file,
                                              viewController: fileListViewController)
            } else {
                let filePresenter = FilePresenter(viewController: fileListViewController)
                filePresenter.present(for: file,
                                      files: [file],
                                      driveFileManager: driveFileManager,
                                      normalFolderHierarchy: false)
            }
        }
    }

    @MainActor public func presentFileList(
        frozenFolder: File,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController
    ) {
        assert(frozenFolder.realm == nil || frozenFolder.isFrozen, "expecting this realm object to be thread safe")
        assert(frozenFolder.isDirectory, "This will only work for folders")

        guard let topViewController = navigationController.topViewController else {
            Log.sceneDelegate("unable to presentFileList, no topViewController", level: .error)
            return
        }

        FilePresenter(viewController: topViewController)
            .presentDirectory(for: frozenFolder,
                              driveFileManager: driveFileManager,
                              animated: false,
                              completion: nil)
    }

    @MainActor public func presentPreviewViewController(
        frozenFiles: [File],
        index: Int,
        driveFileManager: DriveFileManager,
        normalFolderHierarchy: Bool,
        fromActivities: Bool,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        let previewViewController = PreviewViewController.instantiate(files: frozenFiles,
                                                                      index: index,
                                                                      driveFileManager: driveFileManager,
                                                                      normalFolderHierarchy: normalFolderHierarchy,
                                                                      fromActivities: fromActivities)
        navigationController.pushViewController(previewViewController, animated: animated)
    }

    @MainActor public func presentFileDetails(
        frozenFile: File,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        assert(frozenFile.realm == nil || frozenFile.isFrozen, "expecting this realm object to be thread safe")

        let fileDetailViewController = FileDetailViewController.instantiate(
            driveFileManager: driveFileManager,
            file: frozenFile
        )

        navigationController.pushViewController(fileDetailViewController, animated: animated)
    }

    @MainActor public func presentStoreViewController(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        let storeViewController = StoreViewController.instantiate(driveFileManager: driveFileManager)
        navigationController.pushViewController(storeViewController, animated: false)
    }
}
