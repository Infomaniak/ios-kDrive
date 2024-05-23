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
    func showMainViewController(driveFileManager: DriveFileManager)

    func showPreloading(currentAccount: Account)

    func showOnboarding()

    func showAppLock()

    func showLaunchFloatingPanel()

    func showUpdateRequired()

    func showPhotoSyncSettings()
}

/// Something that can present a File within the app
public protocol RouterFileNavigable {
    func present(file: File, driveFileManager: DriveFileManager)

    func present(file: File, driveFileManager: DriveFileManager, office: Bool)
}

public protocol RouterActionable {
    func askForReview()

    /// Ask the user to remove pictures if configured
    func askUserToRemovePicturesIfNecessary()
}

/// Something that can set an arbitrary RootView controller
public protocol RouterRootNavigable {
    /// Something that can set an arbitrary RootView controller
    func setRootViewController(_ viewController: UIViewController,
                               animated: Bool)

    func prepareRootViewController(currentState: RootViewControllerState)
}

public protocol TopmostViewControllerFetchable {
    var topMostViewController: UIViewController? { get }
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

    // Get the current window from the app scene
    private var window: UIWindow? {
        // This is a hack, as the app has only one scene for now.
        // TODO: Support for scene by identifier
        guard let scene = UIApplication.shared.connectedScenes.first,
              let sceneDelegate = scene.delegate as? SceneDelegate,
              let window = sceneDelegate.window else {
            return nil
        }

        return window
    }

    // MARK: TopmostViewControllerFetchable

    public var topMostViewController: UIViewController? {
        var topViewController = window?.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }

    // MARK: RouterRootNavigable

    public func setRootViewController(_ viewController: UIViewController,
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

    public func prepareRootViewController(currentState: RootViewControllerState) {
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

    // MARK: RouterAppNavigable

    public func showMainViewController(driveFileManager: DriveFileManager) {
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

    public func showPreloading(currentAccount: Account) {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = PreloadingViewController(currentAccount: currentAccount)
        window.makeKeyAndVisible()
    }

    public func showOnboarding() {
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

    public func showAppLock() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = LockedAppViewController.instantiate()
        window.makeKeyAndVisible()
    }

    public func showLaunchFloatingPanel() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        let launchPanelsController = LaunchPanelsController()
        if let viewController = window.rootViewController {
            launchPanelsController.pickAndDisplayPanel(viewController: viewController)
        }
    }

    public func showUpdateRequired() {
        guard let window else {
            SentryDebug.captureNoWindow()
            return
        }

        window.rootViewController = DriveUpdateRequiredViewController()
        window.makeKeyAndVisible()
    }

    public func showPhotoSyncSettings() {
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
    }

    // MARK: RouterActionable

    public func askUserToRemovePicturesIfNecessary() {
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
                @InjectService var photoCleaner: PhotoLibraryCleanerServiceable
                await photoCleaner.removePicturesScheduledForDeletion()
            }
        }

        Task { @MainActor in
            window?.rootViewController?.present(alert, animated: true)
        }
    }

    public func askForReview() {
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

    // MARK: RouterFileNavigable

    public func present(file: File, driveFileManager: DriveFileManager) {
        present(file: file, driveFileManager: driveFileManager, office: false)
    }

    public func present(file: File, driveFileManager: DriveFileManager, office: Bool) {
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
                    filePresenter.present(for: file,
                                          files: [file],
                                          driveFileManager: driveFileManager,
                                          normalFolderHierarchy: false)
                }
            }
        }
    }
}
