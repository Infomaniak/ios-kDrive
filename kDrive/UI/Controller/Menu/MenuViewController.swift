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
import kDriveCore
import Sentry
import UIKit

class MenuViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var userAvatarFrame: UIView!
    @IBOutlet weak var userAvatarImageView: UIImageView!
    @IBOutlet weak var userDisplayNameLabel: UILabel!

    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
        }
    }

    private var uploadCountManager: UploadCountManager!

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
        let segue: String?

        static let store = MenuAction(name: KDriveStrings.Localizable.upgradeOfferTitle, image: KDriveAsset.upgradeKdrive.image, segue: "toStoreSegue")

        static let sharedWithMe = MenuAction(name: KDriveStrings.Localizable.sharedWithMeTitle, image: KDriveAsset.folderSelect2.image, segue: "toDriveListSegue")
        static let lastModifications = MenuAction(name: KDriveStrings.Localizable.lastEditsTitle, image: KDriveAsset.clock.image, segue: "toLastModificationsSegue")
        static let images = MenuAction(name: KDriveStrings.Localizable.allPictures, image: KDriveAsset.images.image, segue: "toPhotoListSegue")
        static let myShares = MenuAction(name: KDriveStrings.Localizable.mySharesTitle, image: KDriveAsset.folderSelect.image, segue: "toMySharedSegue")
        static let offline = MenuAction(name: KDriveStrings.Localizable.offlineFileTitle, image: KDriveAsset.availableOffline.image, segue: "toOfflineSegue")
        static let trash = MenuAction(name: KDriveStrings.Localizable.trashTitle, image: KDriveAsset.delete.image, segue: "toTrashSegue")

        static let switchUser = MenuAction(name: KDriveStrings.Localizable.switchUserTitle, image: KDriveAsset.userSwitch.image, segue: "switchUserSegue")
        static let parameters = MenuAction(name: KDriveStrings.Localizable.settingsTitle, image: KDriveAsset.parameters.image, segue: "toParameterSegue")
        static let help = MenuAction(name: KDriveStrings.Localizable.supportTitle, image: KDriveAsset.supportLink.image, segue: nil)
        static let disconnect = MenuAction(name: KDriveStrings.Localizable.buttonLogout, image: KDriveAsset.logout.image, segue: nil)
    }

    private var sections: [Section] = []
    private var currentAccount: Account!

    private var needsContentUpdate = false

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: MenuTopTableViewCell.self)
        tableView.register(cellView: UploadsInProgressTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        currentAccount = AccountManager.instance.currentAccount
        updateTableContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateContentIfNeeded()
    }

    func updateContentIfNeeded() {
        if needsContentUpdate && view.window != nil {
            needsContentUpdate = false
            updateTableContent()
            tableView.reloadData()
        }
    }

    private func observeUploadCount() {
        guard driveFileManager != nil else { return }
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self = self, self.isViewLoaded else { return }
            if let index = self.sections.firstIndex(where: { $0 == .uploads }),
               let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: index)) as? UploadsInProgressTableViewCell {
                if self.uploadCountManager.uploadCount > 0 {
                    // Update cell
                    cell.setUploadCount(self.uploadCountManager.uploadCount)
                } else {
                    // Delete cell
                    self.updateTableContent()
                    self.tableView.reloadData()
                }
            } else {
                // Add cell
                self.updateTableContent()
                self.tableView.reloadData()
            }
        }
    }

    private func updateTableContent() {
        // Show upgrade section if free drive
        if driveFileManager.drive.pack == .free {
            sections = [.header, .upgrade, .more, .options]
        } else {
            sections = [.header, .more, .options]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            sections.insert(.uploads, at: 1)
        }

        // Hide shared with me action if no shared with me drive
        let sharedWithMeInList = Section.more.actions.contains { $0 == .sharedWithMe }
        let hasSharedWithMe = !DriveInfosManager.instance.getDrives(for: AccountManager.instance.currentUserId, sharedWithMe: true).isEmpty
        if sharedWithMeInList && !hasSharedWithMe {
            Section.more.actions.removeFirst()
        } else if !sharedWithMeInList && hasSharedWithMe {
            Section.more.actions.insert(.sharedWithMe, at: 0)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let navController = segue.destination as? UINavigationController, let switchDriveAccountViewController = navController.topViewController as? SwitchDriveViewController {
            switchDriveAccountViewController.delegate = tabBarController as? MainTabViewController
        } else if let storeViewController = segue.destination as? StoreViewController {
            storeViewController.driveFileManager = driveFileManager
        } else if let fileListViewController = segue.destination as? FileListViewController {
            fileListViewController.driveFileManager = driveFileManager
        } else if let photoListViewController = segue.destination as? PhotoListViewController {
            photoListViewController.driveFileManager = driveFileManager
        } else if let parameterTableViewController = segue.destination as? ParameterTableViewController {
            parameterTableViewController.driveFileManager = driveFileManager
        }
    }
}

// MARK: - Table view delegate

extension MenuViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = sections[section]
        if section == .header || section == .uploads {
            return 1
        } else {
            return section.actions.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        if section == .header {
            let cell = tableView.dequeueReusableCell(type: MenuTopTableViewCell.self, for: indexPath)
            cell.selectionStyle = .none
            cell.configureCell(with: driveFileManager.drive, and: currentAccount)
            cell.switchDriveButton.addTarget(self, action: #selector(switchDriveButtonPressed(_:)), for: .touchUpInside)
            return cell
        } else if section == .uploads {
            let cell = tableView.dequeueReusableCell(type: UploadsInProgressTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.progressView.enableIndeterminate()
            cell.setUploadCount(uploadCountManager.uploadCount)
            return cell
        } else {
            let action = section.actions[indexPath.row]
            let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == section.actions.count - 1)
            cell.titleLabel.text = action.name
            cell.titleLabel.numberOfLines = 0
            cell.logoImage.image = action.image
            cell.logoImage.tintColor = KDriveAsset.iconColor.color
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
            let alert = AlertTextViewController(title: KDriveStrings.Localizable.alertRemoveUserTitle, message: KDriveStrings.Localizable.alertRemoveUserDescription(currentAccount.user.displayName), action: KDriveStrings.Localizable.buttonConfirm, destructive: true) {
                AccountManager.instance.removeTokenAndAccount(token: AccountManager.instance.currentAccount.token)
                if let nextAccount = AccountManager.instance.accounts.first {
                    AccountManager.instance.switchAccount(newAccount: nextAccount)
                    (UIApplication.shared.delegate as? AppDelegate)?.refreshCacheData(preload: true, isSwitching: true)
                } else {
                    SentrySDK.setUser(nil)
                    self.tabBarController?.present(OnboardingViewController.instantiate(), animated: true)
                }
                AccountManager.instance.saveAccounts()
            }
            present(alert, animated: true)
        case .help:
            if let url = URL(string: Constants.helpURL) {
                UIApplication.shared.open(url)
            }
        default:
            if let segue = action.segue {
                performSegue(withIdentifier: segue, sender: nil)
            }
        }
    }

    // MARK: - Cell Button Action

    @objc func switchDriveButtonPressed(_ button: UIButton) {
        performSegue(withIdentifier: "toSwitchDriveSegue", sender: nil)
    }
}

extension MenuViewController: SwitchDriveDelegate, SwitchAccountDelegate {
    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {
        self.currentAccount = currentAccount
        needsContentUpdate = true
    }

    func didSwitchCurrentAccount(_ newAccount: Account) {
        currentAccount = newAccount
        needsContentUpdate = true
    }

    func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
        driveFileManager = newDriveFileManager
        needsContentUpdate = true
        updateContentIfNeeded()
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
