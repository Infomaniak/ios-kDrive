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

import kDriveCore
import UIKit

class StoreSuccessViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.store.displayName, "Success"])
    }

    @IBAction func homeButtonPressed(_ sender: IKLargeButton) {
        if let rootViewController = sender.window?.rootViewController as? MainTabViewController {
            rootViewController.dismiss(animated: true)
            (rootViewController.selectedViewController as? UINavigationController)?.popToRootViewController(animated: true)
            rootViewController.selectedIndex = MainTabIndex.home.rawValue
        } else {
            dismiss(animated: true)
        }
    }

    static func instantiate() -> StoreSuccessViewController {
        return Storyboard.menu
            .instantiateViewController(withIdentifier: "StoreSuccessViewController") as! StoreSuccessViewController
    }
}
