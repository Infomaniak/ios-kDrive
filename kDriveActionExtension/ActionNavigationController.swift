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

import InfomaniakCoreUI
import InfomaniakLogin
import kDriveCore
import UIKit

class ActionNavigationController: TitleSizeAdjustingNavigationController {
    private var accountManager: AccountManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Modify sheet size on iPadOS, property is ignored on iOS
        preferredContentSize = CGSize(width: 540, height: 620)
        Logging.initLogging()
        InfomaniakLogin.initWith(clientId: DriveApiFetcher.clientId)
        accountManager = AccountManager.instance

        let saveFileViewController = SaveFileViewController.instantiate(driveFileManager: accountManager.currentDriveFileManager)

        if let itemProviders = (extensionContext?.inputItems as? [NSExtensionItem])?.compactMap(\.attachments).flatMap({ $0 }) {
            saveFileViewController.itemProviders = itemProviders
            viewControllers = [saveFileViewController]
        } else {
            // No items found
            dismiss(animated: true)
        }
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        extensionContext!.completeRequest(returningItems: extensionContext!.inputItems, completionHandler: nil)
    }
}
