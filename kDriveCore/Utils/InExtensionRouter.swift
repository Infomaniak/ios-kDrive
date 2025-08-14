/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import InfomaniakLogin
import UIKit

public struct InExtensionRouter: AppNavigable {
    public init() {}

    public func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {}

    public func navigate(to route: NavigationRoutes) {}

    public func askForReview() async {}

    public func askUserToRemovePicturesIfNecessary() async {}

    public func presentUpSaleSheet() {}

    public func presentKDriveProUpSaleSheet(driveFileManager: DriveFileManager) {}

    public func refreshCacheScanLibraryAndUpload(preload: Bool, isSwitching: Bool) async {}

    public func showMainViewController(driveFileManager: DriveFileManager, selectedIndex: Int?) -> UISplitViewController? {
        return nil
    }

    public func showPreloading(currentAccount: InfomaniakCore.Account) {}

    public func showOnboarding() {}

    public func showAppLock() {}

    public func showLaunchFloatingPanel() {}

    public func showUpdateRequired() {}

    public func showPhotoSyncSettings() {}

    public func showUpsaleFloatingPanel() {}

    public func showLogin(delegate: InfomaniakLoginDelegate) {}

    public func showRegister(delegate: InfomaniakLoginDelegate) {}

    public func showSaveFileVC(from viewController: UIViewController, driveFileManager: DriveFileManager,
                               files: [ImportedFile]) {}

    public func present(file: File, driveFileManager: DriveFileManager) {}

    public func present(file: File, driveFileManager: DriveFileManager, office: Bool) {}

    public func presentFileList(
        frozenFolder: File,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController
    ) {}

    public func presentPreviewViewController(
        frozenFiles: [File],
        index: Int,
        driveFileManager: DriveFileManager,
        normalFolderHierarchy: Bool,
        presentationOrigin: PresentationOrigin,
        navigationController: UINavigationController,
        animated: Bool
    ) {}

    public func presentFileDetails(
        frozenFile: File,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {}

    public func presentStoreViewController(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {}

    public func presentAccountViewController(navigationController: UINavigationController, animated: Bool) {}

    public func presentUploadViewController(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {}

    public func presentPublicShareLocked(_ destinationURL: URL) {}

    public func presentPublicShareExpired() {}

    public func presentPublicShare(
        frozenRootFolder: File,
        publicShareProxy: PublicShareProxy,
        driveFileManager: DriveFileManager,
        apiFetcher: PublicShareApiFetcher
    ) {}

    public func presentPublicShare(
        singleFrozenFile: File,
        virtualFrozenRootFolder: File,
        publicShareProxy: PublicShareProxy,
        driveFileManager: DriveFileManager,
        apiFetcher: PublicShareApiFetcher
    ) {}

    public func setRootViewController(_ viewController: UIViewController, animated: Bool) {}

    public func prepareRootViewController(currentState: RootViewControllerState, restoration: Bool) {}

    public func updateTheme() {}

    public var topMostViewController: UIViewController?

    public var rootViewController: UIViewController?

    @MainActor public func getCurrentController(tabBarViewController: UISplitViewController?) -> UIViewController? { nil }
}
