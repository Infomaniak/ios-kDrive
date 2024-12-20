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

import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import Sentry
import UIKit

final class MenuViewController: UITableViewController, SelectSwitchDriveDelegate {
    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService var appNavigable: AppNavigable

    private let driveFileManager: DriveFileManager
    var uploadCountManager: UploadCountManager?

    private struct Section: Equatable {
        let id: Int
        var actions: [MenuAction]

        static var header = Section(id: 1, actions: [])
        static var uploads = Section(id: 2, actions: [])
        static var upgrade = Section(id: 3, actions: [.store])
        static var options = Section(id: 4, actions: [.switchUser, .parameters, .help, .disconnect])
    }

    private struct MenuAction: Equatable {
        let name: String
        let image: UIImage

        static let store = MenuAction(
            name: KDriveResourcesStrings.Localizable.upgradeOfferTitle,
            image: KDriveResourcesAsset.upgradeKdrive.image
        )
        static let switchUser = MenuAction(
            name: KDriveResourcesStrings.Localizable.switchUserTitle,
            image: KDriveResourcesAsset.userSwitch.image
        )
        static let parameters = MenuAction(
            name: KDriveResourcesStrings.Localizable.settingsTitle,
            image: KDriveResourcesAsset.parameters.image
        )
        static let help = MenuAction(
            name: KDriveResourcesStrings.Localizable.supportTitle,
            image: KDriveResourcesAsset.supportLink.image
        )
        static let disconnect = MenuAction(
            name: KDriveResourcesStrings.Localizable.buttonLogout,
            image: KDriveResourcesAsset.logout.image
        )
    }

    private var sections: [Section] = []
    private var currentAccount: Account?
    private var needsContentUpdate = false

    init(driveFileManager: DriveFileManager) {
        @InjectService var manager: AccountManageable
        currentAccount = manager.currentAccount
        self.driveFileManager = driveFileManager
        super.init(style: .plain)

        observeUploadCount()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        tableView.separatorStyle = .none
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: MenuTopTableViewCell.self)
        tableView.register(cellView: UploadsInProgressTableViewCell.self)
        tableView.register(cellView: UploadsPausedTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        updateTableContent()

        navigationItem.title = KDriveResourcesStrings.Localizable.menuTitle
        navigationItem.hideBackButtonText()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadWifiView),
            name: .reloadWifiView,
            object: nil
        )

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            Task { @MainActor in
                let indexPath = IndexPath(row: 0, section: 1)
                self?.tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        (tabBarController as? PlusButtonObserver)?.updateCenterButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateContentIfNeeded()
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName])
        saveSceneState()
    }

    func updateContentIfNeeded() {
        if needsContentUpdate && view.window != nil {
            needsContentUpdate = false
            updateTableContent()
            tableView.reloadData()
        }
    }

    private func observeUploadCount() {
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self else { return }

            guard let index = sections.firstIndex(where: { $0 == .uploads }),
                  let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: index)) as? UploadsInProgressTableViewCell,
                  let uploadCountManager,
                  uploadCountManager.uploadCount > 0 else {
                // Delete / Add cell
                reloadData()
                return
            }

            // Update cell
            cell.setUploadCount(uploadCountManager.uploadCount)
        }
    }

    private func reloadData() {
        updateTableContent()
        // We need to make sure the table view is not nil as observation might call us early
        tableView?.reloadData()
    }

    private func updateTableContent() {
        // Show upgrade section if free drive
        if driveFileManager.drive.isFreePack {
            sections = [.header, .upgrade, .options]
        } else {
            sections = [.header, .options]
        }

        if let uploadCountManager, uploadCountManager.uploadCount > 0 {
            sections.insert(.uploads, at: 1)
        }
    }

    @objc func reloadWifiView(_ notification: Notification) {
        reloadData()
    }
}

// MARK: - Table view delegate

extension MenuViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = sections[section]
        if section == .header || section == .uploads {
            return 1
        } else {
            return section.actions.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        if section == .header {
            let cell = tableView.dequeueReusableCell(type: MenuTopTableViewCell.self, for: indexPath)
            cell.selectionStyle = .none
            if let currentAccount {
                cell.configureCell(with: driveFileManager.drive, and: currentAccount)
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(switchDriveButtonPressed(_:)))
            cell.switchDriveStackView.addGestureRecognizer(tap)
            cell.switchDriveButton.addTarget(self, action: #selector(switchDriveButtonPressed(_:)), for: .touchUpInside)
            return cell
        } else if section == .uploads {
            if UserDefaults.shared.isWifiOnly && ReachabilityListener.instance.currentStatus == .cellular {
                let cell = tableView.dequeueReusableCell(type: UploadsPausedTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.setUploadCount(uploadCountManager?.uploadCount ?? 0)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(type: UploadsInProgressTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.progressView.enableIndeterminate()
                cell.setUploadCount(uploadCountManager?.uploadCount ?? 0)
                return cell
            }
        } else {
            let action = section.actions[indexPath.row]
            let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == section.actions.count - 1)
            cell.titleLabel.text = action.name
            cell.titleLabel.numberOfLines = 0
            cell.logoImage.image = action.image
            cell.logoImage.tintColor = KDriveResourcesAsset.iconColor.color
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let section = sections[indexPath.section]
        if section == .header {
            return
        } else if section == .uploads {
            let uploadViewController = UploadQueueFoldersViewController.instantiate(driveFileManager: driveFileManager)
            navigationController?.pushViewController(uploadViewController, animated: true)
            return
        }
        let action = section.actions[indexPath.row]
        switch action {
        case .disconnect:
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.alertRemoveUserTitle,
                                                message: KDriveResourcesStrings.Localizable
                                                    .alertRemoveUserDescription(currentAccount?.user.displayName ?? ""),
                                                action: KDriveResourcesStrings.Localizable.buttonConfirm,
                                                destructive: true) {
                self.accountManager.logoutCurrentAccountAndSwitchToNextIfPossible()
                self.appNavigable.prepareRootViewController(
                    currentState: RootViewControllerState.getCurrentState(),
                    restoration: false
                )
            }
            present(alert, animated: true)
        case .help:
            UIApplication.shared.open(URLConstants.support.url)
        case .store:
            let storeViewController = StoreViewController.instantiate(driveFileManager: driveFileManager)
            navigationController?.pushViewController(storeViewController, animated: true)
        case .parameters:
            let parametersViewController = ParameterTableViewController(driveFileManager: driveFileManager)
            navigationController?.pushViewController(parametersViewController, animated: true)
        case .switchUser:
            let switchUserViewController = SwitchUserViewController.instantiate()
            navigationController?.pushViewController(switchUserViewController, animated: true)
        default:
            break
        }
    }

    // MARK: - Cell Button Action

    @objc func switchDriveButtonPressed(_ button: UIButton) {
        let drives = accountManager.drives
        let floatingPanelViewController = FloatingPanelSelectOptionViewController<Drive>.instantiatePanel(options: drives,
                                                                                                          selectedOption: driveFileManager
                                                                                                              .drive,
                                                                                                          headerTitle: KDriveResourcesStrings
                                                                                                              .Localizable
                                                                                                              .buttonSwitchDrive,
                                                                                                          delegate: self)
        present(floatingPanelViewController, animated: true)
    }

    // MARK: - State restoration

    var currentSceneMetadata: [AnyHashable: Any] {
        [:]
    }
}

extension MenuViewController: UpdateAccountDelegate {
    @MainActor func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        self.currentAccount = currentAccount
        needsContentUpdate = true
    }
}

// MARK: - Top scrollable

extension MenuViewController: TopScrollable {
    func scrollToTop() {
        if isViewLoaded {
            tableView.scrollToTop(animated: true, navigationController: navigationController)
        }
    }
}
