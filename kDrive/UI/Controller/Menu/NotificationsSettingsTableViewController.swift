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
import kDriveResources
import UIKit

class NotificationsSettingsTableViewController: BaseGroupedTableViewController {
    private enum NotificationRow {
        case receiveNotification
        case general
        case importFile
        case sharedWithMe
        case newComments
        case notificationMainSetting
    }

    private var rows = [NotificationRow]()
    private var disableSwitch = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = KDriveResourcesStrings.Localizable.notificationTitle

        tableView.register(cellView: ParameterSwitchTableViewCell.self)
        tableView.register(cellView: ParameterAccessDeniedTableViewCell.self)

        updateTableViewContent()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTableViewContent),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        navigationItem.hideBackButtonText()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName, "Notifications"])
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updateTableViewContent() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                self.rows = [.receiveNotification, .general, .importFile, .sharedWithMe, .newComments, .notificationMainSetting]
                self.disableSwitch = true
            } else {
                self.rows = [.receiveNotification, .general, .importFile, .sharedWithMe, .newComments]
                self.disableSwitch = false
            }
            Task { @MainActor in
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .receiveNotification:
            let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.notificationReceiveNotifications
            cell.valueSwitch.isEnabled = !disableSwitch
            cell.valueSwitch.isOn = UserDefaults.shared.isNotificationEnabled
            cell.switchHandler = { [weak self] sender in
                UserDefaults.shared.isNotificationEnabled = sender.isOn
                self?.activateNotification(activate: sender.isOn)
            }
            return cell
        case .general:
            let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.notificationGeneralChannelName
            cell.separator?.isHidden = true
            cell.valueSwitch.isEnabled = !disableSwitch
            cell.valueSwitch.isOn = UserDefaults.shared.generalNotificationEnabled
            cell.switchHandler = { [weak self] sender in
                UserDefaults.shared.generalNotificationEnabled = sender.isOn
                self?.updateSwitchViews()
            }
            return cell
        case .importFile:
            let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.notificationFileUpload
            cell.separator?.isHidden = true
            cell.valueSwitch.isEnabled = !disableSwitch
            cell.valueSwitch.isOn = UserDefaults.shared.importNotificationsEnabled
            cell.switchHandler = { [weak self] sender in
                UserDefaults.shared.importNotificationsEnabled = sender.isOn
                self?.updateSwitchViews()
            }
            return cell
        case .sharedWithMe:
            let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.notificationSharedWithMeChannelName
            cell.separator?.isHidden = true
            cell.valueSwitch.isEnabled = !disableSwitch
            cell.valueSwitch.isOn = UserDefaults.shared.sharingNotificationsEnabled
            cell.switchHandler = { [weak self] sender in
                UserDefaults.shared.sharingNotificationsEnabled = sender.isOn
                self?.updateSwitchViews()
            }
            return cell
        case .newComments:
            let cell = tableView.dequeueReusableCell(type: ParameterSwitchTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isLast: true)
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.notificationCommentChannelName
            cell.valueSwitch.isEnabled = !disableSwitch
            cell.valueSwitch.isOn = UserDefaults.shared.newCommentNotificationsEnabled
            cell.switchHandler = { [weak self] sender in
                UserDefaults.shared.newCommentNotificationsEnabled = sender.isOn
                self?.updateSwitchViews()
            }
            return cell
        case .notificationMainSetting:
            let cell = tableView.dequeueReusableCell(type: ParameterAccessDeniedTableViewCell.self, for: indexPath)
            cell.descriptionLabel.text = KDriveResourcesStrings.Localizable.notificationsDisabledDescription
            return cell
        }
    }

    private func activateNotification(activate: Bool) {
        UserDefaults.shared.sharingNotificationsEnabled = activate
        UserDefaults.shared.importNotificationsEnabled = activate
        UserDefaults.shared.newCommentNotificationsEnabled = activate
        UserDefaults.shared.generalNotificationEnabled = activate
        tableView.reloadData()
    }

    private func updateSwitchViews() {
        if !UserDefaults.shared.importNotificationsEnabled && !UserDefaults.shared.sharingNotificationsEnabled && !UserDefaults
            .shared.newCommentNotificationsEnabled && !UserDefaults.shared.generalNotificationEnabled {
            UserDefaults.shared.isNotificationEnabled = false
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            return
        }
        if UserDefaults.shared.importNotificationsEnabled || UserDefaults.shared.sharingNotificationsEnabled || UserDefaults
            .shared.newCommentNotificationsEnabled || UserDefaults.shared.generalNotificationEnabled {
            UserDefaults.shared.isNotificationEnabled = true
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            return
        }
    }
}
