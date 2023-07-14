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

import kDriveResources
import LocalAuthentication
import UIKit

class LockedAppViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tryToUnlock()
        MatomoUtils.track(view: ["LockedApp"])
    }

    func tryToUnlock() {
        let context = LAContext()
        let reason = KDriveResourcesStrings.Localizable.lockAppTitle
        var error: NSError?
        if #available(iOS 8.0, *) {
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                    DispatchQueue.main.async {
                        if success {
                            self.dismiss(animated: true)
                            (UIApplication.shared.delegate as! AppDelegate).setRootViewController(
                                MainTabViewController.instantiate(),
                                animated: true
                            )
                        }
                    }
                }
            }
        }
    }

    @IBAction func unlockAppButtonClicked(_ sender: UIButton) {
        tryToUnlock()
    }

    class func instantiate() -> LockedAppViewController {
        return Storyboard.main.instantiateViewController(withIdentifier: "LockedAppViewController") as! LockedAppViewController
    }
}
