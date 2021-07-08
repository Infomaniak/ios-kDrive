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

class ParameterTableViewController: UITableViewController {
    var driveFileManager: DriveFileManager!

    private enum ParameterOption {
        case photos
        case theme
        case notifications
        case security
        case wifi
        case about
    }

    private var tableContent: [ParameterOption] {
        if #available(iOS 13.0, *) {
            return [.photos, .theme, .notifications, .security, .wifi, .about]
        } else {
            return [.photos, .notifications, .security, .wifi, .about]
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

    private func getNotificationText() -> String {
        if !UserDefaults.shared.isNotificationEnabled {
            return KDriveStrings.Localizable.notificationDisable
        } else if UserDefaults.shared.generalNotificationEnabled && UserDefaults.shared.newCommentNotificationsEnabled && UserDefaults.shared.importNotificationsEnabled && UserDefaults.shared.sharingNotificationsEnabled {
            return KDriveStrings.Localizable.notificationAll
        } else {
            return KDriveStrings.Localizable.notificationCustom
        }
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
            cell.titleLabel.text = KDriveStrings.Localizable.themeSettingsTitle
            cell.valueLabel.text = UserDefaults.shared.theme.title
            return cell
        case .notifications:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveStrings.Localizable.notificationTitle
            cell.valueLabel.text = getNotificationText()
            return cell
        case .security:
            let cell = tableView.dequeueReusableCell(type: ParameterAboutTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveStrings.Localizable.securityTitle
            return cell
        case .wifi:
            let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.valueSwitch.isOn = UserDefaults.shared.isWifiOnly
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
            performSegue(withIdentifier: "photoSyncSegue", sender: nil)
        case .notifications:
            performSegue(withIdentifier: "notificationsSegue", sender: nil)
        case .security:
            performSegue(withIdentifier: "securitySegue", sender: nil)
        case .about:
            performSegue(withIdentifier: "aboutSegue", sender: nil)
        case .theme:
            performSegue(withIdentifier: "themeSelectionSegue", sender: nil)
        default:
            break
        }
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let photoSyncSettingsViewController = segue.destination as? PhotoSyncSettingsViewController {
            photoSyncSettingsViewController.driveFileManager = driveFileManager
        }
    }
}
