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
    @MainActor func showRecents(
        driveFileManager: DriveFileManager,
        viewController: UISplitViewController,
        recentLink: RecentLink
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

        guard let fileId = recentLink.fileId else {
            let recentViewModel = LastModificationsViewModel(driveFileManager: driveFileManager)
            let recentViewController = FileListViewController(viewModel: recentViewModel)
            navigationController.pushViewController(recentViewController, animated: true)
            return
        }

        await handleSimpleLink(deeplink: recentLink, fileId: fileId, isOfficeLink: false)
    }

    @MainActor func handleRecentLink(recentLink: RecentLink) async {
        guard let driveFileManager = await accountManager
            .getMatchingDriveFileManagerOrSwitchAccount(deeplink: recentLink) else {
            Log.sceneDelegate(
                "NavigationManager: Unable to navigate to .recents without a DriveFileManager",
                level: .error
            )
            deeplinkService.setLastPublicShare(recentLink)
            return
        }

        let freshRootViewController = RootSplitViewController(driveFileManager: driveFileManager, selectedIndex: 1)
        window?.rootViewController = freshRootViewController

        await showRecents(
            driveFileManager: driveFileManager,
            viewController: freshRootViewController,
            recentLink: recentLink
        )
    }
}
