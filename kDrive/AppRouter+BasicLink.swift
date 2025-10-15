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
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import UIKit

@MainActor
extension BasicLinkTab {
    func makeViewModel(driveFileManager: DriveFileManager) -> FileListViewModel {
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

    func makeViewController(driveFileManager: DriveFileManager) -> UIViewController {
        let viewModel = makeViewModel(driveFileManager: driveFileManager)
        return FileListViewController(viewModel: viewModel)
    }
}

public extension AppRouter {
    @MainActor func showBasicTab(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        basicLink: BasicLink
    ) async {
        @LazyInjectService var deeplinkService: DeeplinkServiceable

        defer { deeplinkService.clearLastDeeplink() }

        guard let fileId = basicLink.fileId else {
            let tab = basicLink.destination
            let fileListViewController = tab.makeViewController(driveFileManager: driveFileManager)
            navigationController.pushViewController(fileListViewController, animated: true)
            return
        }

        guard basicLink.destination != BasicLinkTab.trash else {
            await showFolderInTrash(folderId: fileId,
                                    driveFileManager: driveFileManager,
                                    navigationController: navigationController)
            return
        }

        await handleSimpleLink(deeplink: basicLink, fileId: fileId, isOfficeLink: false)
    }

    @MainActor func handleBasicLink(basicLink: BasicLink) async {
        @InjectService var matomo: MatomoUtils
        guard let driveFileManager = await accountManager
            .getMatchingDriveFileManagerOrSwitchAccount(deeplink: basicLink) else {
            Log.sceneDelegate(
                "NavigationManager: Unable to navigate to a tab without a DriveFileManager",
                level: .error
            )
            deeplinkService.setLastDeeplink(basicLink)
            return
        }

        showMainViewController(driveFileManager: driveFileManager, selectedIndex: 1)
        let freshRootViewController = window?.rootViewController

        guard let navigationController =
            getCurrentController(
                rootSplitViewController: freshRootViewController as? UISplitViewController
            ) as? UINavigationController
        else {
            return
        }

        matomo.track(eventWithCategory: .deeplink, name: "internal")
        await showBasicTab(
            driveFileManager: driveFileManager,
            navigationController: navigationController,
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

        showMainViewController(driveFileManager: currentDriveFileManager, selectedIndex: 1)

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
