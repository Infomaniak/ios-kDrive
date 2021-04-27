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

class NotificationsSettingsTableViewController: UITableViewController {

    private enum NotificationRow {
        case receiveNotification
        case importFile
        case sharedWithMe
        case newComments
    }
    private let rows: [NotificationRow] = [.receiveNotification, .importFile, .sharedWithMe, .newComments]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: ParameterSwitchTableViewCell.self)
        tableView.separatorColor = .clear
        navigationController?.navigationBar.sizeToFit()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)

        switch rows[indexPath.row] {
        case .receiveNotification:
            cell.initWithPositionAndShadow(isFirst: true)
            cell.titleLabel.text = KDriveStrings.Localizable.notificationReceiveNotifications
            cell.valueSwitch.isOn = UserDefaults.notificationsEnabled()
            cell.switchDelegate = { sender in
                UserDefaults.store(notificationsEnabled: sender.isOn)
                if UserDefaults.notificationsEnabled() {
                    tableView.reloadRows(at: [IndexPath(row: 1, section: 0), IndexPath(row: 2, section: 0), IndexPath(row: 3, section: 0)], with: .none)
                } else {
                    tableView.reloadRows(at: [IndexPath(row: 1, section: 0), IndexPath(row: 2, section: 0), IndexPath(row: 3, section: 0)], with: .none)
                }
            }
        case .importFile:
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveStrings.Localizable.notificationFileUpload
            cell.separator?.isHidden = true
            cell.valueSwitch.isOn = UserDefaults.importNotificationsEnabled()
            cell.switchDelegate = { [self] sender in
                UserDefaults.store(importNotificationEnabled: sender.isOn)
                updateSwitchViews()
            }
        case .sharedWithMe:
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveStrings.Localizable.notificationSharedWithMeChannelName
            cell.separator?.isHidden = true
            cell.valueSwitch.isOn = UserDefaults.sharingNotificationsEnabled()
            cell.switchDelegate = { [self] sender in
                UserDefaults.store(sharingNotificationEnabled: sender.isOn)
                updateSwitchViews()
            }
        case .newComments:
            cell.initWithPositionAndShadow(isLast: true)
            cell.titleLabel.text = KDriveStrings.Localizable.notificationCommentChannelName
            cell.valueSwitch.isOn = UserDefaults.newCommentNotificationsEnabled()
            cell.switchDelegate = { [self] sender in
                UserDefaults.store(newCommentNotificationEnabled: sender.isOn)
                updateSwitchViews()
            }
        }
        return cell
    }

    private func updateSwitchViews() {
        if !UserDefaults.importNotificationsEnabled() && !UserDefaults.sharingNotificationsEnabled() && !UserDefaults.newCommentNotificationsEnabled() {
            UserDefaults.store(notificationsEnabled: false)
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            return
        }
        if UserDefaults.importNotificationsEnabled() || UserDefaults.sharingNotificationsEnabled() || UserDefaults.newCommentNotificationsEnabled() {
            UserDefaults.store(notificationsEnabled: true)
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            return
        }
    }
}

