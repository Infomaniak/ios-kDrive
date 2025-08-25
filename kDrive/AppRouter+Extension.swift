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
import InfomaniakDI
import kDriveCore
import UIKit

public enum BasicLinkTab: String {
    case recents
    case trash
    case myShares = "my-shares"
    case favorites

    @MainActor func makeViewModel(driveFileManager: DriveFileManager) -> FileListViewModel {
        switch self {
        case .recents:
            return LastModificationsViewModel(driveFileManager: driveFileManager)
        case .trash:
            return TrashListViewModel(driveFileManager: driveFileManager)
        case .myShares:
            return MySharesViewModel(driveFileManager: driveFileManager)
        case .favorites:
            return FavoritesViewModel(driveFileManager: driveFileManager)
        }
    }

    @MainActor func makeViewController(driveFileManager: DriveFileManager) -> UIViewController {
        let viewModel = makeViewModel(driveFileManager: driveFileManager)
        return FileListViewController(viewModel: viewModel)
    }
}

public extension AppRouter {
    @MainActor func showBasicTab(
        driveFileManager: DriveFileManager,
        viewController: UISplitViewController,
        basicLink: BasicLink
    ) async {
        @LazyInjectService var deeplinkService: DeeplinkServiceable

        defer { deeplinkService.clearLastDeeplink() }

        guard let navigationController =
            getCurrentController(
                tabBarViewController: viewController
            ) as? UINavigationController
        else {
            return
        }

        guard let fileId = basicLink.fileId else {
            if let tab = BasicLinkTab(rawValue: basicLink.destination) {
                let fileListViewController = tab.makeViewController(driveFileManager: driveFileManager)
                navigationController.pushViewController(fileListViewController, animated: true)
            }
            return
        }

        guard basicLink.destination != BasicLinkTab.trash.rawValue else {
            await showFolderInTrash(folderId: fileId,
                                    driveFileManager: driveFileManager,
                                    navigationController: navigationController)
            return
        }

        await handleSimpleLink(deeplink: basicLink, fileId: fileId, isOfficeLink: false)
    }

    @MainActor func handleBasicLink(basicLink: BasicLink) async {
        guard let driveFileManager = await accountManager
            .getMatchingDriveFileManagerOrSwitchAccount(deeplink: basicLink) else {
            Log.sceneDelegate(
                "NavigationManager: Unable to navigate to a tab without a DriveFileManager",
                level: .error
            )
            deeplinkService.setLastDeeplink(basicLink)
            return
        }

        let freshRootViewController = RootSplitViewController(driveFileManager: driveFileManager, selectedIndex: 1)
        window?.rootViewController = freshRootViewController

        await showBasicTab(
            driveFileManager: driveFileManager,
            viewController: freshRootViewController,
            basicLink: basicLink
        )
    }

    @MainActor func handleSimpleLink(deeplink: Any, fileId: Int, isOfficeLink: Bool) async {
        guard let driveFileManager = await accountManager
            .getMatchingDriveFileManagerOrSwitchAccount(deeplink: deeplink) else {
            Log.sceneDelegate(
                "NavigationManager: Unable to navigate without a DriveFileManager",
                level: .error
            )
            deeplinkService.setLastDeeplink(deeplink)
            return
        }
        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        let freshRootViewController = RootSplitViewController(driveFileManager: currentDriveFileManager, selectedIndex: 1)
        window?.rootViewController = freshRootViewController

        let fileActionsHelper = FileActionsHelper()
        fileActionsHelper.openFile(id: fileId, driveFileManager: driveFileManager, office: isOfficeLink)
    }

    @MainActor private func showFolderInTrash(
        folderId: Int,
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController
    ) async {
        var folder: File?
        if let fetchResponse = try? await driveFileManager.apiFetcher.trashedFiles(
            drive: driveFileManager.drive
        ) {
            folder = fetchResponse.validApiResponse.data.first { $0.id == folderId }
        }

        let destinationViewModel = TrashListViewModel(driveFileManager: driveFileManager, currentDirectory: folder)
        let destinationViewController = FileListViewController(viewModel: destinationViewModel)

        navigationController.pushViewController(destinationViewController, animated: true)
    }
}
