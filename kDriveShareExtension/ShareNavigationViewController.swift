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

import UIKit
import InfomaniakCoreUI
import InfomaniakLogin
import kDriveCore
import InfomaniakDI

class ShareNavigationViewController: TitleSizeAdjustingNavigationController {

    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook()

    @LazyInjectService var accountManager: AccountManageable

    public override func viewDidLoad() {
        // log
        super.viewDidLoad()
        // Modify sheet size on iPadOS, property is ignored on iOS
        preferredContentSize = CGSize(width: 540, height: 620)
        Logging.initLogging()

        let saveViewController = SaveFileViewController.instantiate(driveFileManager: accountManager.currentDriveFileManager)

        if let attachments = (self.extensionContext?.inputItems.first as? NSExtensionItem)?.attachments {
            saveViewController.itemProviders = attachments
            viewControllers = [saveViewController]
        } else {
            dismiss(animated: true)
        }
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
    }

}
