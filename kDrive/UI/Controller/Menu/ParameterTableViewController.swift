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

import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakCoreUIResources
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

    lazy var packId = DrivePackId(rawValue: driveFileManager.drive.pack.name)

    var mykSuiteEnabled = false

    private enum ParameterSection: Int, CaseIterable {
        case mykSuite
        case general

        func title(packId: DrivePackId?) -> String {
            switch self {
            case .mykSuite:
                if packId == .myKSuite {
                    return "my kSuite"
                } else if packId == .myKSuitePlus {
                    return "my kSuite+"
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
                @InjectService var accountManager: AccountManageable
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
        case joinBeta
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
            case .joinBeta:
                return CoreUILocalizable.joinTheBetaButton
            case .deleteAccount:
                return KDriveResourcesStrings.Localizable.deleteMyAccount
            }
        }
    }

    private var visibleRows: [GeneralParameterRow] {
        GeneralParameterRow.allCases.filter { $0 != .joinBeta || !Bundle.main.isRunningInTestFlight }
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
        checkMykSuiteEnabledAndRefresh()
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
        return nil
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let currentSection: ParameterSection?
        if mykSuiteEnabled {
            currentSection = ParameterSection(rawValue: section)
        } else {
            currentSection = ParameterSection.general
        }

        guard let currentSection else { return nil }

        let headerView = UIView()
        headerView.backgroundColor = .clear

        let label = IKLabel()
        label.text = currentSection.title(packId: packId)
        label.font = TextStyle.header3.font

        label.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        return headerView
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard mykSuiteEnabled else {
            return 1
        }

        return ParameterSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard mykSuiteEnabled else {
            return visibleRows.count
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
        guard mykSuiteEnabled else {
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
        let row = visibleRows[indexPath.row]
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
        case .security, .storage, .about, .joinBeta, .deleteAccount:
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
            isLast: indexPath.row == MykSuiteParameterRow.allCases.count - 1
        )

        let row = MykSuiteParameterRow.allCases[indexPath.row]
        switch row {
        case .email:
            cell.titleLabel.text = row.title
            cell.titleLabel.font = TextStyle.body1.font
            cell.selectionStyle = .none
        case .mySubscription:
            cell.titleLabel.text = row.title
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard mykSuiteEnabled else {
            didSelectGeneralRowAt(indexPath: indexPath)
            return
        }

        switch indexPath.section {
        case ParameterSection.mykSuite.rawValue:
            didSelectMykSuiteRowAt(indexPath: indexPath)
        case ParameterSection.general.rawValue:
            didSelectGeneralRowAt(indexPath: indexPath)
        default:
            return
        }
    }

    private func didSelectMykSuiteRowAt(indexPath: IndexPath) {
        let row = MykSuiteParameterRow.allCases[indexPath.row]
        guard row == MykSuiteParameterRow.mySubscription else { return }
        guard let currentAccount = accountManager.currentAccount else { return }
        let dashboardViewController = MyKSuiteDashboardViewBridgeController.instantiate(
            apiFetcher: driveFileManager.apiFetcher,
            currentAccount: currentAccount
        )
        MatomoUtils.track(eventWithCategory: .myKSuite, name: "openDashboard")
        navigationController?.present(dashboardViewController, animated: true)
    }

    private func didSelectGeneralRowAt(indexPath: IndexPath) {
        let row = visibleRows[indexPath.row]
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
        case .joinBeta:
            UIApplication.shared.open(URLConstants.testFlight.url)
            MatomoUtils.track(eventWithCategory: .settings, name: "joinBetaProgram")
        case .deleteAccount:
            let deleteAccountViewController = DeleteAccountViewController.instantiateInViewController(
                delegate: self,
                accessToken: driveFileManager.apiFetcher.currentToken?.accessToken,
                navBarColor: KDriveResourcesAsset.backgroundColor.color,
                navBarButtonColor: KDriveResourcesAsset.infomaniakColor.color
            )
            navigationController?.present(deleteAccountViewController, animated: true)
        }
    }

    private func checkMykSuiteEnabledAndRefresh() {
        Task { @MainActor in
            @InjectService var mykSuiteStore: MyKSuiteStore
            let packIsMykSuite: Bool
            if await mykSuiteStore.getMyKSuite(id: accountManager.currentUserId) != nil,
               packId == .myKSuite || packId == .myKSuitePlus {
                packIsMykSuite = true
            } else {
                packIsMykSuite = false
            }

            self.mykSuiteEnabled = packIsMykSuite
            self.tableView.reloadData()
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
