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
import InfomaniakDI
import kDriveResources
import UIKit

class LockedAppViewController: UIViewController {
    @LazyInjectService private var appLockHelper: AppLockHelper

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tryToUnlock()
        MatomoUtils.track(view: ["LockedApp"])
    }

    func tryToUnlock() {
        Task {
            let success = try await appLockHelper.evaluatePolicy(reason: KDriveResourcesStrings.Localizable.lockAppTitle)

            guard success else { return }
            appLockHelper.setTime()
            let currentState = RootViewControllerState.getCurrentState()
            (UIApplication.shared.delegate as? AppDelegate)?.prepareRootViewController(currentState: currentState)
        }
    }

    @IBAction func unlockAppButtonClicked(_ sender: UIButton) {
        tryToUnlock()
    }

    class func instantiate() -> LockedAppViewController {
        return Storyboard.main.instantiateViewController(withIdentifier: "LockedAppViewController") as! LockedAppViewController
    }
}
