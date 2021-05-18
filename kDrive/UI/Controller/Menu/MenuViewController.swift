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
import InfomaniakCore
import Sentry

class MenuViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var userAvatarFrame: UIView!
    @IBOutlet weak var userAvatarImageView: UIImageView!
    @IBOutlet weak var userDisplayNameLabel: UILabel!

    var driveFileManager: DriveFileManager!

    private struct MenuAction: Equatable {
        let name: String
        let image: UIImage
        let segue: String

        static let sharedWithMeAction = MenuAction(name: KDriveStrings.Localizable.sharedWithMeTitle, image: KDriveAsset.folderSelect2.image, segue: "toDriveListSegue")
        static let lastModificationAction = MenuAction(name: KDriveStrings.Localizable.lastEditsTitle, image: KDriveAsset.clock.image, segue: "toLastModificationsSegue")
        static let imagesAction = MenuAction(name: KDriveStrings.Localizable.allPictures, image: KDriveAsset.images.image, segue: "toPhotoListSegue")
        static let mySharedAction = MenuAction(name: KDriveStrings.Localizable.mySharesTitle, image: KDriveAsset.folderSelect.image, segue: "toMySharedSegue")
        static let offlineAction = MenuAction(name: KDriveStrings.Localizable.offlineFileTitle, image: KDriveAsset.availableOffline.image, segue: "toOfflineSegue")
        static let trashAction = MenuAction(name: KDriveStrings.Localizable.trashTitle, image: KDriveAsset.delete.image, segue: "toTrashSegue")

        static let switchUserAction = MenuAction(name: KDriveStrings.Localizable.switchUserTitle, image: KDriveAsset.userSwitch.image, segue: "switchUserSegue")
        static let parametersAction = MenuAction(name: KDriveStrings.Localizable.settingsTitle, image: KDriveAsset.parameters.image, segue: "toParameterSegue")
        static let disconnectAction = MenuAction(name: KDriveStrings.Localizable.buttonLogout, image: KDriveAsset.logout.image, segue: "disconnect")
    }

    private var tableContent: [[MenuAction]] = [
        [],
        [.sharedWithMeAction, .lastModificationAction, .imagesAction, .offlineAction, .mySharedAction, .trashAction],
        [.switchUserAction, .parametersAction, .disconnectAction]
    ]
    private var currentAccount: Account!

    private var needsContentUpdate = false

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: MenuTopTableViewCell.self)
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

    private func updateTableContent() {
        guard tableContent.count > 1 else {
            return
        }

        // Hide shared with me action if no shared with me drive
        let sharedWithMeInList = tableContent[1].contains(where: { $0 == .sharedWithMeAction })
        let hasSharedWithMe = !DriveInfosManager.instance.getDrives(for: AccountManager.instance.currentAccount.userId, sharedWithMe: true).isEmpty
        if sharedWithMeInList && !hasSharedWithMe {
            tableContent[1].removeFirst()
        } else if !sharedWithMeInList && hasSharedWithMe {
            tableContent[1].insert(.sharedWithMeAction, at: 0)
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
        if let navController = segue.destination as? UINavigationController, let switchDriveAccountViewController = navController.topViewController as? SwitchDriveViewController {
            switchDriveAccountViewController.delegate = tabBarController as? MainTabViewController
        } else if let photoListViewController = segue.destination as? PhotoListViewController {
            photoListViewController.driveFileManager = driveFileManager
        } else if let parameterTableViewController = segue.destination as? ParameterTableViewController {
            parameterTableViewController.driveFileManager = driveFileManager
        }
    }
}

// MARK: - UITableView Delegate

extension MenuViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return tableContent.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return tableContent[section].count
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if #available(iOS 13.0, *) {
        } else {
            // Fix for iOS 12
            if let cell = cell as? MenuTableViewCell {
                cell.logoImage.tintColor = KDriveAsset.iconColor.color
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(type: MenuTopTableViewCell.self, for: indexPath)
            cell.selectionStyle = .none
            cell.configureCell(with: driveFileManager.drive, and: currentAccount)
            cell.switchDriveButton.addTarget(self, action: #selector(switchDriveButtonPressed(_:)), for: .touchUpInside)
            return cell
        } else {
            let cellContent = tableContent[indexPath.section][indexPath.row]
            let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
            let isLast = indexPath.row == tableContent[indexPath.section].count - 1
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: isLast)
            cell.titleLabel.text = cellContent.name
            cell.logoImage.image = cellContent.image
            cell.logoImage.tintColor = KDriveAsset.iconColor.color
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section > 0 {
            let segue = tableContent[indexPath.section][indexPath.row].segue
            if segue != "" {
                if segue == "disconnect" {
                    let alert = AlertTextViewController(title: KDriveStrings.Localizable.alertRemoveUserTitle, message: KDriveStrings.Localizable.alertRemoveUserDescription(currentAccount.user.displayName), action: KDriveStrings.Localizable.buttonConfirm, destructive: true) {
                        AccountManager.instance.removeTokenAndAccount(token: AccountManager.instance.currentAccount.token)
                        if let nextAccount = AccountManager.instance.accounts.first {
                            AccountManager.instance.switchAccount(newAccount: nextAccount)
                            (UIApplication.shared.delegate as? AppDelegate)?.refreshCacheData(preload: true, isSwitching: true)
                        } else {
                            SentrySDK.setUser(nil)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.tabBarController?.present(OnboardingViewController.instantiate(), animated: true)
                            }
                        }
                        AccountManager.instance.saveAccounts()
                    }
                    present(alert, animated: true)
                } else {
                    performSegue(withIdentifier: segue, sender: nil)
                }
            }
        }
    }

    //MARK: Cell Button Action

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
