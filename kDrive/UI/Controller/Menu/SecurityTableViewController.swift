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
import kDriveCore

class SecurityTableViewController: UITableViewController {

    private enum SecurityOption {
        case appLock
        case fileProviderExtension
    }

    private var tableContent: [SecurityOption] {
        return [.appLock, .fileProviderExtension]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.register(cellView: ParameterWifiTableViewCell.self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableContent[indexPath.row] {
        case .appLock:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true)
            cell.titleLabel.text = KDriveStrings.Localizable.appSecurityTitle
            cell.valueLabel.text = UserDefaults.shared.isAppLockEnabled ? KDriveStrings.Localizable.allActivated : KDriveStrings.Localizable.allDisabled
            return cell
        case .fileProviderExtension:
            let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isLast: true)
            cell.valueSwitch.isOn = UserDefaults.shared.isFileProviderExtensionEnabled
            cell.titleLabel.text = KDriveStrings.Localizable.fileProviderExtensionTitle
            cell.detailsLabel.text = KDriveStrings.Localizable.fileProviderExtensionDescription
            cell.switchHandler = { sender in
                UserDefaults.shared.isFileProviderExtensionEnabled = sender.isOn
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableContent[indexPath.row] {
        case .appLock:
            let appLockSettingsVC = AppLockSettingsViewController.instantiate()
            appLockSettingsVC.closeActionHandler = {
                appLockSettingsVC.dismiss(animated: true)
                self.tableView.reloadData()
            }
            present(appLockSettingsVC, animated: true)
        default:
            break
        }
    }
}
