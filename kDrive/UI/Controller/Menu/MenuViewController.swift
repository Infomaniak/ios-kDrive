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

    private let driveFileManager: DriveFileManager
    var uploadCountManager: UploadCountManager?

    private struct Section: Equatable {
        let id: Int
        var actions: [MenuAction]

        static var header = Section(id: 1, actions: [])
        static var uploads = Section(id: 2, actions: [])
        static var upgrade = Section(id: 3, actions: [.store])
        static var more = Section(id: 4, actions: [.sharedWithMe, .lastModifications, .images, .offline, .myShares, .trash])
        static var options = Section(id: 5, actions: [.switchUser, .parameters, .help, .disconnect])
    }

    private struct MenuAction: Equatable {
        let name: String
        let image: UIImage

        static let store = MenuAction(
            name: KDriveResourcesStrings.Localizable.upgradeOfferTitle,
            image: KDriveResourcesAsset.upgradeKdrive.image
        )
        static let sharedWithMe = MenuAction(
            name: KDriveResourcesStrings.Localizable.sharedWithMeTitle,
            image: KDriveResourcesAsset.folderSelect2.image
        )
        static let lastModifications = MenuAction(
            name: KDriveResourcesStrings.Localizable.lastEditsTitle,
            image: KDriveResourcesAsset.clock.image
        )
        static let images = MenuAction(
            name: KDriveResourcesStrings.Localizable.galleryTitle,
            image: KDriveResourcesAsset.images.image
        )
        static let myShares = MenuAction(
            name: KDriveResourcesStrings.Localizable.mySharesTitle,
            image: KDriveResourcesAsset.folderSelect.image
        )
        static let offline = MenuAction(
            name: KDriveResourcesStrings.Localizable.offlineFileTitle,
            image: KDriveResourcesAsset.availableOffline.image
        )
        static let trash = MenuAction(
            name: KDriveResourcesStrings.Localizable.trashTitle,
            image: KDriveResourcesAsset.delete.image
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

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = KDriveResourcesAsset.backgroundColor.color
        tableView.separatorStyle = .none
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: MenuTopTableViewCell.self)
        tableView.register(cellView: UploadsInProgressTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        updateTableContent()

        navigationItem.title = KDriveResourcesStrings.Localizable.menuTitle
        navigationItem.hideBackButtonText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        (tabBarController as? MainTabViewController)?.enableCenterButton(isEnabled: true)
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
            sections = [.header, .upgrade, .more, .options]
        } else {
            sections = [.header, .more, .options]
        }

        if let uploadCountManager, uploadCountManager.uploadCount > 0 {
            sections.insert(.uploads, at: 1)
        }

        // Hide shared with me action if no shared with me drive
        guard let sectionIndex = sections.firstIndex(of: .more) else { return }
        let sharedWithMeInList = sections[sectionIndex].actions.contains(.sharedWithMe)
        let hasSharedWithMe = !DriveInfosManager.instance.getDrives(for: accountManager.currentUserId, sharedWithMe: true).isEmpty
        if sharedWithMeInList && !hasSharedWithMe {
            sections[sectionIndex].actions.removeFirst()
        } else if !sharedWithMeInList && hasSharedWithMe {
            sections[sectionIndex].actions.insert(.sharedWithMe, at: 0)
        }
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
            cell.switchDriveButton.addTarget(self, action: #selector(switchDriveButtonPressed(_:)), for: .touchUpInside)
            return cell
        } else if section == .uploads {
            let cell = tableView.dequeueReusableCell(type: UploadsInProgressTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.progressView.enableIndeterminate()
            cell.setUploadCount(uploadCountManager?.uploadCount ?? 0)
            return cell
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
        case .lastModifications:
            createAndPushFileListViewController(
                with: LastModificationsViewModel(driveFileManager: driveFileManager),
                as: FileListViewController.self
            )
        case .trash:
            createAndPushFileListViewController(
                with: TrashListViewModel(driveFileManager: driveFileManager),
                as: FileListViewController.self
            )
        case .myShares:
            createAndPushFileListViewController(
                with: MySharesViewModel(driveFileManager: driveFileManager),
                as: FileListViewController.self,
                shouldHideBottomBar: false
            )
        case .offline:
            createAndPushFileListViewController(
                with: OfflineFilesViewModel(driveFileManager: driveFileManager),
                as: FileListViewController.self
            )
        case .images:
            createAndPushFileListViewController(
                with: PhotoListViewModel(driveFileManager: driveFileManager),
                as: PhotoListViewController.self
            )
        case .disconnect:
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.alertRemoveUserTitle,
                                                message: KDriveResourcesStrings.Localizable
                                                    .alertRemoveUserDescription(currentAccount?.user.displayName ?? ""),
                                                action: KDriveResourcesStrings.Localizable.buttonConfirm,
                                                destructive: true) {
                self.accountManager.logoutCurrentAccountAndSwitchToNextIfPossible()
            }
            present(alert, animated: true)
        case .help:
            UIApplication.shared.open(URLConstants.support.url)
        case .store:
            let storeViewController = StoreViewController.instantiate(driveFileManager: driveFileManager)
            navigationController?.pushViewController(storeViewController, animated: true)
        case .parameters:
            let parameterTableViewController = ParameterTableViewController.instantiate(driveFileManager: driveFileManager)
            navigationController?.pushViewController(parameterTableViewController, animated: true)
        case .sharedWithMe:
            let sharedDrivesViewController = SharedDrivesViewController.instantiate()
            navigationController?.pushViewController(sharedDrivesViewController, animated: true)
        case .switchUser:
            let switchUserViewController = SwitchUserViewController.instantiate()
            navigationController?.pushViewController(switchUserViewController, animated: true)
        default:
            break
        }
    }

    private func createAndPushFileListViewController<T: FileListViewController>(
        with viewModel: FileListViewModel,
        as _: T.Type,
        shouldHideBottomBar: Bool = true
    ) {
        let fileListViewController = T.instantiate(viewModel: viewModel)
        fileListViewController.hidesBottomBarWhenPushed = shouldHideBottomBar
        navigationController?.pushViewController(fileListViewController, animated: true)
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
}

extension MenuViewController: UpdateAccountDelegate {
    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
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
