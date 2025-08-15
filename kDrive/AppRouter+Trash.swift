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

public extension AppRouter {
    @MainActor func showTrash(
        driveFileManager: DriveFileManager,
        viewController: UISplitViewController,
        trashLink: TrashLink
    ) async {
        @LazyInjectService var deeplinkService: DeeplinkServiceable

        defer { deeplinkService.clearLastPublicShare() }

        guard let navigationController =
            getCurrentController(
                tabBarViewController: viewController
            ) as? UINavigationController
        else {
            return
        }

        let rootTrash = DriveFileManager.trashRootFile
        let myTrashViewModel = TrashListViewModel(driveFileManager: driveFileManager, currentDirectory: rootTrash)
        let myTrashViewController = FileListViewController(viewModel: myTrashViewModel)
        navigationController.pushViewController(myTrashViewController, animated: true)

        guard let trashedFolderId = trashLink.folderId else {
            return
        }

        await showFolderInTrash(folderId: trashedFolderId,
                                driveFileManager: driveFileManager,
                                navigationController: navigationController)
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

    @MainActor func handleTrashLink(trashLink: TrashLink) async {
        guard let driveFileManager = await accountManager
            .getMatchingDriveFileManagerOrSwitchAccount(deeplink: trashLink) else {
            Log.sceneDelegate(
                "NavigationManager: Unable to navigate to .trashFiles without a DriveFileManager",
                level: .error
            )
            deeplinkService.setLastPublicShare(trashLink)
            return
        }

        let freshRootViewController = RootSplitViewController(driveFileManager: driveFileManager, selectedIndex: 1)
        window?.rootViewController = freshRootViewController

        await showTrash(driveFileManager: driveFileManager, viewController: freshRootViewController, trashLink: trashLink)
    }
}
