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

import kDriveCore
import UIKit

struct PublicShareAction {
    @MainActor func addToMyDrive(
        publicShareProxy: PublicShareProxy,
        currentUserDriveFileManager: DriveFileManager,
        selectedItemsIds: [Int],
        exceptItemIds: [Int],
        onPresentViewController: (UIViewController, Bool) -> Void,
        onDismissViewController: (() -> Void)?
    ) {
        let saveNavigationViewController = SaveFileViewController.instantiateInNavigationController(
            driveFileManager: currentUserDriveFileManager,
            publicShareProxy: publicShareProxy,
            publicShareFileIds: selectedItemsIds,
            publicShareExceptIds: exceptItemIds,
            onDismissViewController: onDismissViewController
        )

        onPresentViewController(saveNavigationViewController, true)
    }
}
