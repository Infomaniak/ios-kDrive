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
import InfomaniakCoreUIKit
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import SafariServices
import UIKit
import VersionChecker

public struct AppRouter: AppNavigable {
    @LazyInjectService private var appExtensionRouter: AppExtensionRoutable
    @LazyInjectService private var appRestorationService: AppRestorationServiceable
    @LazyInjectService private var driveInfosManager: DriveInfosManager
    @LazyInjectService private var keychainHelper: KeychainHelper
    @LazyInjectService private var reviewManager: ReviewManageable
    @LazyInjectService private var availableOfflineManager: AvailableOfflineManageable
    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var infomaniakLogin: InfomaniakLoginable
    @LazyInjectService private var deeplinkService: DeeplinkServiceable

    @LazyInjectService var backgroundDownloadSessionManager: BackgroundDownloadSessionManager
    @LazyInjectService var backgroundUploadSessionManager: BackgroundUploadSessionManager

    /// Get the current window from the app scene
    @MainActor private var window: UIWindow? {
        let scene = UIApplication.shared.connectedScenes.first { scene in
            guard let delegate = scene.delegate,
                  delegate is SceneDelegate else {
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

    // MARK: Routable

    public func navigate(to route: NavigationRoutes) {
        guard let rootViewController = window?.rootViewController else {
            SentryDebug.captureNoWindow()
            Log.sceneDelegate("NavigationManager: Unable to navigate without a root view controller", level: .error)
            return
        }

        // Get presented view controller
        var viewController = rootViewController
        while let presentedViewController = viewController.presentedViewController {
            viewController = presentedViewController
        }

        switch route {
        case .saveFiles(let files):
            guard let driveFileManager = accountManager.currentDriveFileManager else {
                Log.sceneDelegate("NavigationManager: Unable to navigate to .saveFile without a DriveFileManager", level: .error)
                return
            }

            showSaveFileVC(from: viewController, driveFileManager: driveFileManager, files: files)

        case .store(let driveId, let userId):
            guard let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId) else {
                Log.sceneDelegate("NavigationManager: Unable to navigate to .store without a DriveFileManager", level: .error)
                return
            }

            // Show store
            showStore(from: viewController, driveFileManager: driveFileManager)
        }
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
            if #available(iOS 15, *) {
                self.askToUpSaleIfQuotaReached()
            }

            Task {
                await askForReview()
                await askUserToRemovePicturesIfNecessary()
                deeplinkService.processDeeplinksPostAuthentication()
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
        let shouldRestoreApplicationState = appRestorationService.shouldRestoreApplicationState
        var indexToUse: Int?
        if shouldRestoreApplicationState,
           let sceneUserInfo,
           let index = sceneUserInfo[SceneRestorationKeys.selectedIndex.rawValue] as? Int {
            indexToUse = index
        }

        let tabBarViewController = showMainViewController(driveFileManager: driveFileManager, selectedIndex: indexToUse)

        guard shouldRestoreApplicationState else {
            Log.sceneDelegate("Restoration disabled", level: .error)
            appRestorationService.saveRestorationVersion()
            return
        }

        Task { @MainActor in
            guard restoration, let tabBarViewController else {
                return
            }

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
        let frozenFile = database.fetchObject(ofType: File.self) { lazyCollection in
            lazyCollection
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
        let frozenFile = database.fetchObject(ofType: File.self) { lazyCollection in
            lazyCollection
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
        guard sceneUserInfo[SceneRestorationValues.driveId.rawValue] is Int,
              let fileIds = sceneUserInfo[SceneRestorationValues.Carousel.filesIds.rawValue] as? [Int],
              let currentIndex = sceneUserInfo[SceneRestorationValues.Carousel.currentIndex.rawValue] as? Int,
              let normalFolderHierarchy = sceneUserInfo[SceneRestorationValues.Carousel.normalFolderHierarchy.rawValue] as? Bool,
              let rawPresentationOrigin = sceneUserInfo[SceneRestorationValues.Carousel.presentationOrigin.rawValue] as? String,
              let presentationOrigin = PresentationOrigin(rawValue: rawPresentationOrigin) else {
            Log.sceneDelegate("metadata issue for PreviewController :\(sceneUserInfo)", level: .error)
            return
        }

        let database = driveFileManager.database
        let frozenFetchedFiles = database.fetchResults(ofType: File.self) { lazyCollection in
            lazyCollection
                .filter("id IN %@", fileIds)
                .freezeIfNeeded()
        }

        let frozenFilesToRestore = Array(frozenFetchedFiles)

        await presentPreviewViewController(
            frozenFiles: frozenFilesToRestore,
            index: currentIndex,
            driveFileManager: driveFileManager,
            normalFolderHierarchy: normalFolderHierarchy,
            presentationOrigin: presentationOrigin,
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

    @MainActor public func showUpsaleFloatingPanel() {
        guard let topMostViewController else {
            return
        }

        let upsaleFloatingPanelController = UpsaleViewController
            .instantiateInFloatingPanel(rootViewController: topMostViewController)
        topMostViewController.present(upsaleFloatingPanelController, animated: true)
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
        rootViewController.selectedIndex = MainTabBarIndex.profile.rawValue

        guard let navController = rootViewController.selectedViewController as? UINavigationController else {
            return
        }

        let photoSyncSettingsViewController = PhotoSyncSettingsViewController()
        navController.popToRootViewController(animated: false)
        navController.pushViewController(photoSyncSettingsViewController, animated: true)
    }

    public func showSaveFileVC(from viewController: UIViewController, driveFileManager: DriveFileManager, files: [ImportedFile]) {
        let vc = SaveFileViewController.instantiateInNavigationController(driveFileManager: driveFileManager, files: files)
        viewController.present(vc, animated: true)
    }

    @MainActor public func showRegister(delegate: InfomaniakLoginDelegate) {
        guard let topMostViewController else {
            return
        }

        MatomoUtils.track(eventWithCategory: .account, name: "openCreationWebview")
        let registerViewController = RegisterViewController.instantiateInNavigationController(delegate: delegate)
        topMostViewController.present(registerViewController, animated: true)
    }

    @MainActor public func showLogin(delegate: InfomaniakLoginDelegate) {
        guard let topMostViewController else {
            return
        }

        MatomoUtils.track(eventWithCategory: .account, name: "openLoginWebview")
        infomaniakLogin.webviewLoginFrom(viewController: topMostViewController,
                                         hideCreateAccountButton: true,
                                         delegate: delegate)
    }

    // MARK: AppExtensionRouter

    public func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {
        appExtensionRouter.showStore(from: viewController, driveFileManager: driveFileManager)
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

    @MainActor public func askToUpSaleIfQuotaReached() {
        // TODO: Check quota
        presentUpSaleSheet()
    }

    @MainActor public func presentUpSaleSheet() {
        guard let window,
              let rootViewController = window.rootViewController else {
            return
        }

        rootViewController.dismiss(animated: true) {
            if #available(iOS 15, *) {
                let floatingPanelViewController = MyKSuiteFloatingPanelBridgeController()
                let myKSuiteViewController = MyKSuiteBridgeViewController()
                floatingPanelViewController.isRemovalInteractionEnabled = true
                floatingPanelViewController.set(contentViewController: myKSuiteViewController)

                rootViewController.present(floatingPanelViewController, animated: false)
            } else {
                fatalError("kaput")
            }
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

    @MainActor public func presentPublicShareLocked(_ destinationURL: URL) {
        guard let window,
              let rootViewController = window.rootViewController else {
            return
        }

        rootViewController.dismiss(animated: false) {
            let viewController = LockedFolderViewController()
            viewController.destinationURL = destinationURL
            let publicShareNavigationController = UINavigationController(rootViewController: viewController)
            publicShareNavigationController.modalPresentationStyle = .fullScreen
            publicShareNavigationController.modalTransitionStyle = .coverVertical

            rootViewController.present(publicShareNavigationController, animated: true, completion: nil)
        }
    }

    @MainActor public func presentPublicShareExpired() {
        guard let window,
              let rootViewController = window.rootViewController else {
            return
        }

        rootViewController.dismiss(animated: false) {
            let viewController = UnavaillableFolderViewController()
            let publicShareNavigationController = UINavigationController(rootViewController: viewController)
            publicShareNavigationController.modalPresentationStyle = .fullScreen
            publicShareNavigationController.modalTransitionStyle = .coverVertical

            rootViewController.present(publicShareNavigationController, animated: true, completion: nil)
        }
    }

    @MainActor public func presentPublicShare(
        frozenRootFolder: File,
        publicShareProxy: PublicShareProxy,
        driveFileManager: DriveFileManager,
        apiFetcher: PublicShareApiFetcher
    ) {
        guard let window,
              let rootViewController = window.rootViewController else {
            return
        }

        if let topMostViewController, (topMostViewController as? LockedAppViewController) != nil {
            return
        }

        rootViewController.dismiss(animated: false) {
            let configuration = FileListViewModel.Configuration(selectAllSupported: true,
                                                                rootTitle: nil,
                                                                emptyViewType: .emptyFolder,
                                                                supportsDrop: false,
                                                                leftBarButtons: [.cancel],
                                                                rightBarButtons: [.downloadAll],
                                                                matomoViewPath: [
                                                                    MatomoUtils.Views.menu.displayName,
                                                                    "publicShare"
                                                                ])

            let viewModel = PublicShareViewModel(publicShareProxy: publicShareProxy,
                                                 sortType: .nameAZ,
                                                 driveFileManager: driveFileManager,
                                                 currentDirectory: frozenRootFolder,
                                                 apiFetcher: apiFetcher,
                                                 configuration: configuration)
            let viewController = FileListViewController(viewModel: viewModel)
            viewModel.onDismissViewController = { [weak viewController] in
                viewController?.dismiss(animated: false)
            }
            let publicShareNavigationController = UINavigationController(rootViewController: viewController)
            publicShareNavigationController.modalPresentationStyle = .fullScreen
            publicShareNavigationController.modalTransitionStyle = .coverVertical

            rootViewController.present(publicShareNavigationController, animated: true, completion: nil)
        }
    }

    @MainActor public func present(file: File, driveFileManager: DriveFileManager) {
        present(file: file, driveFileManager: driveFileManager, office: false)
    }

    @MainActor public func present(file: File, driveFileManager: DriveFileManager, office: Bool) {
        guard let rootViewController = window?.rootViewController as? MainTabViewController else {
            return
        }

        rootViewController.dismiss(animated: false) {
            rootViewController.selectedIndex = MainTabBarIndex.files.rawValue

            guard let navController = rootViewController.selectedViewController as? UINavigationController else {
                return
            }

            guard !file.isRoot else { return }

            if let fileListViewController = navController.topViewController as? FileListViewController {
                guard fileListViewController.viewModel.currentDirectory.id != file.id else {
                    return
                }

                navController.popToRootViewController(animated: false)
            }

            guard let rootMenuViewController = navController.topViewController as? RootMenuViewController else {
                return
            }

            if office {
                OnlyOfficeViewController.open(driveFileManager: driveFileManager,
                                              file: file,
                                              viewController: rootMenuViewController)
            } else {
                let filePresenter = FilePresenter(viewController: rootMenuViewController)
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
        presentationOrigin: PresentationOrigin,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        guard index <= frozenFiles.count else {
            Log.sceneDelegate("unable to presentPreviewViewController, invalid data", level: .error)
            return
        }

        let previewViewController = PreviewViewController.instantiate(files: frozenFiles,
                                                                      index: index,
                                                                      driveFileManager: driveFileManager,
                                                                      normalFolderHierarchy: normalFolderHierarchy,
                                                                      presentationOrigin: presentationOrigin)
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
        navigationController.pushViewController(storeViewController, animated: animated)
    }

    @MainActor public func presentAccountViewController(
        navigationController: UINavigationController,
        animated: Bool
    ) {
        let accountViewController = SwitchUserViewController.instantiate()
        navigationController.pushViewController(accountViewController, animated: animated)
    }
}
