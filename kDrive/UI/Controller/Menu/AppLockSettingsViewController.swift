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

import AppLock
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import LocalAuthentication
import UIKit

class AppLockSettingsViewController: UIViewController {
    @IBOutlet var tableView: UITableView!
    @IBOutlet var navigationBar: UINavigationBar!

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService private var appLockHelper: AppLockHelping

    var closeActionHandler: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.shadowImage = UIImage()
        navigationBar.setBackgroundImage(UIImage(), for: .default)

        tableView.register(cellView: ParameterSwitchTableViewCell.self)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: [MatomoUtils.View.menu.displayName, MatomoUtils.View.settings.displayName,
                            MatomoUtils.View.security.displayName, "AppLock"])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 26.0, *) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                additionalSafeAreaInsets.top = 12
            } else {
                additionalSafeAreaInsets.top = 16
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        closeActionHandler?()
    }

    @IBAction func buttonCloseClicked(_ sender: Any) {
        closeActionHandler?()
    }

    class func instantiate() -> AppLockSettingsViewController {
        return Storyboard.menu
            .instantiateViewController(withIdentifier: "AppLockSettingsViewController") as! AppLockSettingsViewController
    }
}

extension AppLockSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
        cell.valueLabel.text = KDriveCoreStrings.Localizable.buttonSettingsLockApp
        cell.valueSwitch.isOn = UserDefaults.shared.isAppLockEnabled
        cell.switchHandler = { [weak self] sender in
            guard let self else { return }

            let context = LAContext()
            let reason = KDriveResourcesStrings.Localizable.appSecurityDescription
            var error: NSError?
            matomo.track(eventWithCategory: .settings, name: "lockApp", value: sender.isOn)

            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                    Task { @MainActor in
                        if success {
                            UserDefaults.shared.isAppLockEnabled = sender.isOn
                            self.appLockHelper.setTime()
                        } else {
                            sender.setOn(!sender.isOn, animated: true)
                        }
                    }
                }
            } else {
                sender.setOn(!sender.isOn, animated: true)
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
