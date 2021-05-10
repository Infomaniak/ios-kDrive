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

class ParameterTableViewController: UITableViewController {

    var driveFileManager: DriveFileManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.register(cellView: ParameterAboutTableViewCell.self)
        tableView.register(cellView: ParameterWifiTableViewCell.self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row >= 0 && indexPath.row <= 2 {
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            if indexPath.row == 0 {
                cell.initWithPositionAndShadow(isFirst: true)
                cell.titleLabel.text = KDriveStrings.Localizable.syncSettingsTitle
                cell.valueLabel.text = PhotoLibraryUploader.instance.isSyncEnabled ? KDriveStrings.Localizable.allActivated : KDriveStrings.Localizable.allDisabled
            } else if indexPath.row == 1 {
                cell.initWithPositionAndShadow()
                cell.titleLabel.text = KDriveStrings.Localizable.notificationTitle
                cell.valueLabel.text = KDriveStrings.Localizable.notificationAll
            } else if indexPath.row == 2 {
                cell.initWithPositionAndShadow()
                cell.titleLabel.text = KDriveStrings.Localizable.appSecurityTitle
                cell.valueLabel.text = UserDefaults.shared.isAppLockEnabled ? KDriveStrings.Localizable.allActivated : KDriveStrings.Localizable.allDisabled
            }
            return cell
        } else if indexPath.row == 3 {
            let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.wifiSwitch.isOn = UserDefaults.shared.isWifiOnly
            cell.switchHandler = { sender in
                UserDefaults.shared.isWifiOnly = sender.isOn
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(type: ParameterAboutTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isLast: true)
            cell.titleLabel.text = KDriveStrings.Localizable.aboutTitle
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            self.performSegue(withIdentifier: "photoSyncSegue", sender: nil)
        } else if indexPath.row == 1 {
            self.performSegue(withIdentifier: "notificationsSegue", sender: nil)
        } else if indexPath.row == 2 {
            let appLockSettingsVC = AppLockSettingsViewController.instantiate()
            appLockSettingsVC.closeActionHandler = {
                appLockSettingsVC.dismiss(animated: true)
                self.tableView.reloadData()
            }
            present(appLockSettingsVC, animated: true)
        } else if indexPath.row == 4 {
            self.performSegue(withIdentifier: "aboutSegue", sender: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let photoSyncSettingsViewController = segue.destination as? PhotoSyncSettingsViewController {
            photoSyncSettingsViewController.driveFileManager = driveFileManager
        }
    }
}
