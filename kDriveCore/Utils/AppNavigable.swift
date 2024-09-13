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

import Foundation
import InfomaniakCore
import UIKit

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

    @MainActor func showSaveFileVC(from viewController: UIViewController, driveFileManager: DriveFileManager, file: ImportedFile)
}

/// Routing methods available from both the AppExtension mode and App
public protocol AppExtensionRoutable {
    /// Show native appstore inapp upsale in context
    @MainActor func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager)
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
    ///   - fromPhotoList: Opening from an photoList
    ///   - navigationController: The navigation controller to use
    ///   - animated: Should be animated
    @MainActor func presentPreviewViewController(
        frozenFiles: [File],
        index: Int,
        driveFileManager: DriveFileManager,
        normalFolderHierarchy: Bool,
        presentationOrigin: PresentationOrigin,
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

    /// Present the SwitchAccountViewController
    /// - Parameters:
    ///   - navigationController: The navigation controller to use
    ///   - animated: Should be animated
    @MainActor func presentAccountViewController(
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
public typealias AppNavigable = AppExtensionRoutable
    & Routable
    & RouterActionable
    & RouterAppNavigable
    & RouterFileNavigable
    & RouterRootNavigable
    & TopmostViewControllerFetchable
