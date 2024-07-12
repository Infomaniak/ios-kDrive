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

class AppLockSettingsViewController: UIViewController {
    @IBOutlet var faceIdSwitch: UISwitch!
    @IBOutlet var navigationBar: UINavigationBar!

    var closeActionHandler: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)

        faceIdSwitch.setOn(UserDefaults.shared.isAppLockEnabled, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName,
                                 MatomoUtils.Views.security.displayName, "AppLock"])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        closeActionHandler?()
    }

    @IBAction func buttonCloseClicked(_ sender: Any) {
        closeActionHandler?()
    }

    @IBAction func didChangeSwitchValue(_ sender: UISwitch) {
        let context = LAContext()
        let reason = KDriveResourcesStrings.Localizable.appSecurityDescription
        var error: NSError?
        MatomoUtils.track(eventWithCategory: .settings, name: "lockApp", value: sender.isOn)
        if #available(iOS 8.0, *) {
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                    Task { @MainActor in
                        if success {
                            UserDefaults.shared.isAppLockEnabled = sender.isOn
                        } else {
                            sender.setOn(!sender.isOn, animated: true)
                        }
                    }
                }
            } else {
                sender.setOn(!sender.isOn, animated: true)
            }
        }
    }

    class func instantiate() -> AppLockSettingsViewController {
        return Storyboard.menu
            .instantiateViewController(withIdentifier: "AppLockSettingsViewController") as! AppLockSettingsViewController
    }
}
