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

import InfomaniakLogin
import kDriveCore
import kDriveResources
import UIKit
import SafariServices
import Sentry
import WebKit

class ParameterTableViewController: UITableViewController {
    var driveFileManager: DriveFileManager!

    private enum ParameterRow: CaseIterable {
        case photos
        case theme
        case notifications
        case security
        case wifi
        case storage
        case about
        case deleteAccount

        var title: String {
            switch self {
            case .photos:
                return KDriveResourcesStrings.Localizable.syncSettingsTitle
            case .theme:
                return KDriveResourcesStrings.Localizable.themeSettingsTitle
            case .notifications:
                return KDriveResourcesStrings.Localizable.notificationTitle
            case .security:
                return KDriveResourcesStrings.Localizable.securityTitle
            case .wifi:
                return KDriveResourcesStrings.Localizable.settingsOnlyWifiSyncTitle
            case .storage:
                return KDriveResourcesStrings.Localizable.manageStorageTitle
            case .about:
                return KDriveResourcesStrings.Localizable.aboutTitle
            case .deleteAccount:
                return KDriveResourcesStrings.Localizable.deleteMyAccount
            }
        }

        var segue: String? {
            switch self {
            case .photos:
                return "photoSyncSegue"
            case .theme:
                return "themeSelectionSegue"
            case .notifications:
                return "notificationsSegue"
            case .security:
                return "securitySegue"
            case .wifi, .storage, .deleteAccount:
                return nil
            case .about:
                return "aboutSegue"
            }
        }
    }

    private var tableContent: [ParameterRow] {
        return ParameterRow.allCases
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: ParameterTableViewCell.self)
        tableView.register(cellView: ParameterAboutTableViewCell.self)
        tableView.register(cellView: ParameterWifiTableViewCell.self)

        navigationItem.hideBackButtonText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, MatomoUtils.Views.settings.displayName])
    }

    private func getNotificationText() -> String {
        if !UserDefaults.shared.isNotificationEnabled {
            return KDriveResourcesStrings.Localizable.notificationDisable
        } else if UserDefaults.shared.generalNotificationEnabled && UserDefaults.shared.newCommentNotificationsEnabled && UserDefaults.shared.importNotificationsEnabled && UserDefaults.shared.sharingNotificationsEnabled {
            return KDriveResourcesStrings.Localizable.notificationAll
        } else {
            return KDriveResourcesStrings.Localizable.notificationCustom
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableContent[indexPath.row]
        switch row {
        case .photos, .theme, .notifications:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == tableContent.count - 1)
            cell.titleLabel.text = row.title
            if row == .photos {
                cell.valueLabel.text = PhotoLibraryUploader.instance.isSyncEnabled ? KDriveResourcesStrings.Localizable.allActivated : KDriveResourcesStrings.Localizable.allDisabled
            } else if row == .theme {
                cell.valueLabel.text = UserDefaults.shared.theme.title
            } else if row == .notifications {
                cell.valueLabel.text = getNotificationText()
            }
            return cell
        case .wifi:
            let cell = tableView.dequeueReusableCell(type: ParameterWifiTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow()
            cell.valueSwitch.isOn = UserDefaults.shared.isWifiOnly
            cell.switchHandler = { sender in
                MatomoUtils.track(eventWithCategory: .settings, name: "onlyWifiTransfer", value: sender.isOn)
                UserDefaults.shared.isWifiOnly = sender.isOn
            }
            return cell
        case .security, .storage, .about, .deleteAccount:
            let cell = tableView.dequeueReusableCell(type: ParameterAboutTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == tableContent.count - 1)
            cell.titleLabel.text = row.title
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = tableContent[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        if let segueIdentifier = row.segue {
            performSegue(withIdentifier: segueIdentifier, sender: self)
        } else if row == .storage {
            navigationController?.pushViewController(StorageTableViewController(style: .grouped), animated: true)
        } else if row == .deleteAccount {
            let deleteAccountDeletionViewController = DeleteAccountViewController.instantiateInViewController(
                delegate: self,
                accessToken: driveFileManager.apiFetcher.currentToken?.accessToken,
                navBarColor: KDriveResourcesAsset.backgroundColor.color,
                navBarButtonColor: KDriveResourcesAsset.infomaniakColor.color
            )
            navigationController?.present(deleteAccountDeletionViewController, animated: true)
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
}

extension ParameterTableViewController: DeleteAccountDelegate {
    func didCompleteDeleteAccount() {
        AccountManager.instance.removeTokenAndAccount(token: AccountManager.instance.currentAccount.token)
        if let nextAccount = AccountManager.instance.accounts.first {
            AccountManager.instance.switchAccount(newAccount: nextAccount)
            (UIApplication.shared.delegate as? AppDelegate)?.refreshCacheData(preload: true, isSwitching: true)
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarAccountDeleted)
        } else {
            SentrySDK.setUser(nil)
            tabBarController?.present(OnboardingViewController.instantiate(), animated: true)
        }
        AccountManager.instance.saveAccounts()
    }

    func didFailDeleteAccount(context: [String: Any]?) {
        SentrySDK.capture(message: "Failed to load Infomaniak Manager") { scope in
            scope.setContext(value: context ?? [:], key: "link")
        }
        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarErrorAccountDeletionErrorWhileDeleting)
    }
}
