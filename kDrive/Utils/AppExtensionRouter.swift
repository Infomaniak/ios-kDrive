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

import CocoaLumberjackSwift
import Foundation
import kDriveCore

/// Routing methods available from both the AppExtension mode and App
public struct AppExtensionRouter: AppExtensionRoutable {
    public func showStore(from viewController: UIViewController, driveFileManager: DriveFileManager) {
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
}
