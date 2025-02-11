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

import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import MyKSuite
import Sentry
import UIKit

class ParameterTableViewController: BaseGroupedTableViewController {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var photoLibraryUploader: PhotoLibraryUploader
    @LazyInjectService var appNavigable: AppNavigable

    let driveFileManager: DriveFileManager

    lazy var packId = DrivePackId.myKSuite // TODO: Remove hardcode for -> DrivePackId(rawValue: driveFileManager.drive.pack.name)

    lazy var isMykSuiteEnabled: Bool = {
        if packId == .myKSuite || packId == .myKSuitePlus {
            return true
        } else {
            return false
        }
    }()

    private enum ParameterSection: Int, CaseIterable {
        case mykSuite
        case general

        func title(packId: DrivePackId?) -> String {
            switch self {
            case .mykSuite:
                if packId == .myKSuite {
                    return "my kSuite"
                } else if packId == .myKSuitePlus {
                    return "my kSuite plus"
                } else {
                    return ""
                }
            case .general:
                return KDriveResourcesStrings.Localizable.settingsSectionGeneral
            }
        }
    }

    private enum MykSuiteParameterRow: CaseIterable {
        case email
        case mySubscription

        var title: String {
            switch self {
            case .email:
                @LazyInjectService var accountManager: AccountManageable
                return accountManager.currentAccount?.user.email ?? ""
            case .mySubscription:
                return MyKSuiteLocalizable.iosMyKSuiteDashboardSubscriptionButton
            }
        }
    }

    private enum GeneralParameterRow: CaseIterable {
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
    }

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
        super.init()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = KDriveResourcesStrings.Localizable.settingsTitle

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
        } else if UserDefaults.shared.generalNotificationEnabled && UserDefaults.shared
            .newCommentNotificationsEnabled && UserDefaults.shared.importNotificationsEnabled && UserDefaults.shared
            .sharingNotificationsEnabled {
            return KDriveResourcesStrings.Localizable.notificationAll
        } else {
            return KDriveResourcesStrings.Localizable.notificationCustom
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let currentSection = ParameterSection(rawValue: section) else {
            return nil
        }
        return currentSection.title(packId: packId)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard isMykSuiteEnabled else {
            return 1
        }

        return ParameterSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard isMykSuiteEnabled else {
            return GeneralParameterRow.allCases.count
        }

        switch section {
        case ParameterSection.mykSuite.rawValue:
            return MykSuiteParameterRow.allCases.count
        case ParameterSection.general.rawValue:
            return GeneralParameterRow.allCases.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard isMykSuiteEnabled else {
            return generalCell(tableView, forRowAt: indexPath)
        }

        switch indexPath.section {
        case ParameterSection.mykSuite.rawValue:
            return mykSuiteCell(tableView, forRowAt: indexPath)
        case ParameterSection.general.rawValue:
            return generalCell(tableView, forRowAt: indexPath)
        default:
            fatalError("invalid indexPath: \(indexPath)")
        }
    }

    private func generalCell(_ tableView: UITableView, forRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = GeneralParameterRow.allCases[indexPath.row]
        switch row {
        case .photos, .theme, .notifications:
            let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(
                isFirst: indexPath.row == 0,
                isLast: indexPath.row == GeneralParameterRow.allCases.count - 1
            )
            cell.titleLabel.text = row.title
            if row == .photos {
                cell.valueLabel.text = photoLibraryUploader.isSyncEnabled ? KDriveResourcesStrings.Localizable
                    .allActivated : KDriveResourcesStrings.Localizable.allDisabled
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
            cell.initWithPositionAndShadow(
                isFirst: indexPath.row == 0,
                isLast: indexPath.row == GeneralParameterRow.allCases.count - 1
            )
            cell.titleLabel.text = row.title
            return cell
        }
    }

    private func mykSuiteCell(_ tableView: UITableView, forRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ParameterTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(
            isFirst: indexPath.row == 0,
            isLast: indexPath.row == GeneralParameterRow.allCases.count - 1
        )

        let row = MykSuiteParameterRow.allCases[indexPath.row]
        switch row {
        case .email:
            cell.titleLabel.text = row.title
        case .mySubscription:
            cell.titleLabel.text = row.title
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case ParameterSection.mykSuite.rawValue:
            let row = MykSuiteParameterRow.allCases[indexPath.row]
            let dashboardViewController = MyKSuiteDashboardViewBridgeController(apiFetcher: driveFileManager.apiFetcher)
            navigationController?.present(dashboardViewController, animated: true)
        case ParameterSection.general.rawValue:
            let row = GeneralParameterRow.allCases[indexPath.row]
            switch row {
            case .storage:
                navigationController?.pushViewController(StorageTableViewController(style: .grouped), animated: true)
            case .photos:
                navigationController?.pushViewController(PhotoSyncSettingsViewController(), animated: true)
            case .theme:
                navigationController?.pushViewController(SelectThemeTableViewController(), animated: true)
            case .notifications:
                navigationController?.pushViewController(NotificationsSettingsTableViewController(), animated: true)
            case .security:
                navigationController?.pushViewController(SecurityTableViewController(), animated: true)
            case .wifi:
                break
            case .about:
                navigationController?.pushViewController(AboutTableViewController(), animated: true)
            case .deleteAccount:
                let deleteAccountViewController = DeleteAccountViewController.instantiateInViewController(
                    delegate: self,
                    accessToken: driveFileManager.apiFetcher.currentToken?.accessToken,
                    navBarColor: KDriveResourcesAsset.backgroundColor.color,
                    navBarButtonColor: KDriveResourcesAsset.infomaniakColor.color
                )
                navigationController?.present(deleteAccountViewController, animated: true)
            }
        default:
            return
        }
    }
}

extension ParameterTableViewController: DeleteAccountDelegate {
    func didCompleteDeleteAccount() {
        if let currentAccount = accountManager.currentAccount {
            accountManager.removeTokenAndAccount(account: currentAccount)
        }

        if let nextAccount = accountManager.accounts.first {
            accountManager.switchAccount(newAccount: nextAccount)
            Task {
                await appNavigable.refreshCacheScanLibraryAndUpload(preload: true, isSwitching: true)
            }
        } else {
            SentrySDK.setUser(nil)
        }
        accountManager.saveAccounts()
        appNavigable.prepareRootViewController(currentState: RootViewControllerState.getCurrentState(), restoration: false)
        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarAccountDeleted)
    }

    func didFailDeleteAccount(error: InfomaniakLoginError) {
        SentryDebug.capture(error: error)
        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarErrorAccountDeletion)
    }
}
