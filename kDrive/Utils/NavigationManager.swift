/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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

import CocoaLumberjackSwift
import InfomaniakDI
import kDriveCore
import UIKit

final class NavigationManager: NavigationManageable {
    @LazyInjectService var accountManager: AccountManageable

    func navigate(to route: NavigationRoutes) {
        #if ISEXTENSION
        DDLogError("NavigationManager: navigate(to:) NOOP in extension mode")
        #else
        guard let appDelegate = UIApplication.shared.delegate,
              let rootViewController = appDelegate.window??.rootViewController else {
            DDLogError("NavigationManager: Unable to navigate without a root view controller")
            return
        }

        // Get presented view controller
        var viewController = rootViewController
        while let presentedViewController = viewController.presentedViewController {
            viewController = presentedViewController
        }

        switch route {
        case .saveFile(let file):
            guard let driveFileManager = accountManager.currentDriveFileManager else {
                DDLogError("NavigationManager: Unable to navigate to .saveFile without a DriveFileManager")
                return
            }

            showSaveFileVC(from: viewController, driveFileManager: driveFileManager, file: file)

        case .store(let driveId, let userId):
            guard let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId) else {
                DDLogError("NavigationManager: Unable to navigate to .store without a DriveFileManager")
                return
            }

            // Show store
            showStore(from: viewController, driveFileManager: driveFileManager)
        }
        #endif
    }

    func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {
        #if ISEXTENSION
        UIConstants.openUrl(
            "kdrive:store?userId=\(driveFileManager.apiFetcher.currentToken!.userId)&driveId=\(driveFileManager.drive.id)",
            from: viewController
        )
        #else
        let storeViewController = StoreViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
        viewController.present(storeViewController, animated: true)
        #endif
    }

    func showSaveFileVC(from viewController: UIViewController, driveFileManager: DriveFileManager, file: ImportedFile) {
        #if ISEXTENSION
        DDLogError("NavigationManager: showSaveFileVC(from:) NOOP in extension mode")
        #else
        let vc = SaveFileViewController.instantiateInNavigationController(driveFileManager: driveFileManager, file: file)
        viewController.present(vc, animated: true)
        #endif
    }
}
