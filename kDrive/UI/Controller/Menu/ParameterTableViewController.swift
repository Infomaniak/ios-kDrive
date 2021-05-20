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
    
    private enum parameterOption {
        case photos
        case theme
        case notifications
        case appLock
        case wifi
        case about
    }
    
    private var tableContent: [parameterOption] {
        if #available(iOS 13.0, *) {
            return [.photos, .theme, .notifications, .appLock, .wifi, .about]
        } else {
            return [.photos, .notifications, .appLock, .wifi, .about]
        }
    }
    
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
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableContent[indexPath.row] {
        case .photos:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true)
            cell.titleLabel.text = KDriveStrings.Localizable.syncSettingsTitle
            cell.valueLabel.text = PhotoLibraryUploader.instance.isSyncEnabled ? KDriveStrings.Localizable.allActivated : KDriveStrings.Localizable.allDisabled
            return cell
        case .theme:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = "Thème"
            cell.valueLabel.text = "Clair"
            return cell
        case .notifications:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveStrings.Localizable.notificationTitle
            cell.valueLabel.text = KDriveStrings.Localizable.notificationAll
            return cell
        case .appLock:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveStrings.Localizable.appSecurityTitle
            cell.valueLabel.text = UserDefaults.shared.isAppLockEnabled ? KDriveStrings.Localizable.allActivated : KDriveStrings.Localizable.allDisabled
            return cell
        case .wifi:
            let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.wifiSwitch.isOn = UserDefaults.shared.isWifiOnly
            cell.switchHandler = { sender in
                UserDefaults.shared.isWifiOnly = sender.isOn
            }
            return cell
        case .about:
            let cell = tableView.dequeueReusableCell(type: ParameterAboutTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isLast: true)
            cell.titleLabel.text = KDriveStrings.Localizable.aboutTitle
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableContent[indexPath.row] {
        case .photos:
            self.performSegue(withIdentifier: "photoSyncSegue", sender: nil)
        case .notifications:
            self.performSegue(withIdentifier: "notificationsSegue", sender: nil)
        case .appLock:
            let appLockSettingsVC = AppLockSettingsViewController.instantiate()
            appLockSettingsVC.closeActionHandler = {
                appLockSettingsVC.dismiss(animated: true)
                self.tableView.reloadData()
            }
            present(appLockSettingsVC, animated: true)
        case .about:
            self.performSegue(withIdentifier: "aboutSegue", sender: nil)
        case .theme:
            performSegue(withIdentifier: "themeSelectionSegue", sender: nil)
        default:
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let photoSyncSettingsViewController = segue.destination as? PhotoSyncSettingsViewController {
            photoSyncSettingsViewController.driveFileManager = driveFileManager
        }
    }
}
