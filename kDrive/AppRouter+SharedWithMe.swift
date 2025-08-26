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

import Foundation
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

public extension AppRouter {
    @MainActor func showSharedWithMeView(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController
    ) {
        let destinationViewModel = SharedWithMeViewModel(driveFileManager: driveFileManager)
        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        navigationController.pushViewController(destinationViewController, animated: true)
    }

    @MainActor func showSharedFileIdView(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        driveId: Int,
        fileId: Int
    ) async {
        let rawPresentationOrigin = "fileList"
        guard let presentationOrigin = PresentationOrigin(rawValue: rawPresentationOrigin),
              let frozenFile = await driveFileManager.getFrozenFileFromAPI(
                  driveId: driveId,
                  fileId: fileId
              )
        else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSharedWithMeLink)
            return
        }

        presentPreviewViewController(
            frozenFiles: [frozenFile],
            index: 0,
            driveFileManager: driveFileManager,
            normalFolderHierarchy: true,
            presentationOrigin: presentationOrigin,
            navigationController: navigationController,
            animated: true
        )
    }

    @MainActor func showSharedFolderIdView(driveFileManager: DriveFileManager,
                                           navigationController: UINavigationController,
                                           driveId: Int,
                                           folderId: Int) async {
        guard let frozenFolder = await driveFileManager.getFrozenFileFromAPI(
            driveId: driveId,
            fileId: folderId
        ) else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSharedWithMeLink)
            return
        }

        let configuration = FileListViewModel.Configuration(
            emptyViewType: .emptyFolder,
            supportsDrop: true,
            rightBarButtons: [.search]
        )
        let destinationViewModel = ConcreteFileListViewModel(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: frozenFolder
        )

        Task {
            try await destinationViewModel.loadFiles()
        }

        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        navigationController.pushViewController(destinationViewController, animated: true)
    }

    @MainActor func showSharedWithMe(
        driveFileManager: DriveFileManager,
        viewController: UISplitViewController,
        sharedWithMeLink: SharedWithMeLink
    ) async {
        @LazyInjectService var deeplinkService: DeeplinkServiceable

        guard let navigationController =
            getCurrentController(
                tabBarViewController: viewController
            ) as? UINavigationController
        else {
            return
        }

        let sharedWithMeDriveFileManager = driveFileManager.instanceWith(context: .sharedWithMe)

        if let fileId = sharedWithMeLink.fileId, let sharedDriveId = sharedWithMeLink.sharedDriveId {
            await showSharedFileIdView(
                driveFileManager: sharedWithMeDriveFileManager,
                navigationController: navigationController,
                driveId: sharedDriveId,
                fileId: fileId
            )
        } else if let folderId = sharedWithMeLink.folderId, let sharedDriveId = sharedWithMeLink.sharedDriveId {
            await showSharedFolderIdView(
                driveFileManager: sharedWithMeDriveFileManager,
                navigationController: navigationController,
                driveId: sharedDriveId,
                folderId: folderId
            )
        } else {
            showSharedWithMeView(driveFileManager: sharedWithMeDriveFileManager, navigationController: navigationController)
        }

        deeplinkService.clearLastDeeplink()
    }

    @MainActor func handleSharedWithMeLink(sharedWithMeLink: SharedWithMeLink) async {
        guard let driveFileManager = await accountManager
            .getMatchingDriveFileManagerOrSwitchAccount(deeplink: sharedWithMeLink) else {
            Log.sceneDelegate(
                "NavigationManager: Unable to navigate to .sharedWithMe without a matching DriveFileManager",
                level: .error
            )
            deeplinkService.setLastDeeplink(sharedWithMeLink)
            return
        }

        let freshRootViewController = RootSplitViewController(driveFileManager: driveFileManager, selectedIndex: 1)
        window?.rootViewController = freshRootViewController

        await showSharedWithMe(
            driveFileManager: driveFileManager,
            viewController: freshRootViewController,
            sharedWithMeLink: sharedWithMeLink
        )
    }
}
