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
import DropDown

class ShareAndRightsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private enum ShareAndRightsSections {
        case invite
        case link
        case access
    }
    private let sections: [ShareAndRightsSections] = [.invite, .link, .access]

    var shareLinkIsActive = false
    var file: File!
    var sharedFile: SharedFile?
    var removeUsers: [Int] = []
    var removeEmails: [String] = []

    private var selectedUserIndex: Int?
    private var selectedTagIndex: Int?
    private var selectedInvitationIndex: Int?
    private var shareLinkRights = false
    private var initialLoading = true

    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Documentation says it's better to put it in AppDelegate but why ?
        DropDown.startListeningToKeyboard()

        navigationController?.navigationBar.isTranslucent = true

        tableView.register(cellView: InviteUserTableViewCell.self)
        tableView.register(cellView: UsersAccessTableViewCell.self)
        tableView.register(cellView: ShareLinkTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        updateShareList()
        hideKeyboardWhenTappedAround()
        setTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !initialLoading {
            updateShareList()
        }
        initialLoading = false
    }

    func setTitle() {
        guard file != nil else { return }
        title = file.isDirectory ? KDriveStrings.Localizable.fileShareDetailsFolderTitle(file.name) : KDriveStrings.Localizable.fileShareDetailsFileTitle(file.name)
    }

    func updateShareList() {
        driveFileManager?.apiFetcher.getShareListFor(file: file) { response, _ in
            if let data = response?.data {
                self.sharedFile = data
                self.removeUsers = data.users.map(\.id) + data.invitations.compactMap { $0?.userId }
                self.removeEmails = data.invitations.compactMap { invitation -> String? in
                    if invitation?.userId != nil {
                        return nil
                    }
                    return invitation?.email
                }
                self.tableView.reloadData()
            }
        }
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }

    class func instantiate() -> ShareAndRightsViewController {
        return Storyboard.files.instantiateViewController(withIdentifier: "ShareAndRightsViewController") as! ShareAndRightsViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(file.id, forKey: "FileId")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let fileId = coder.decodeInteger(forKey: "FileId")
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        file = driveFileManager.getCachedFile(id: fileId)
        setTitle()
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension ShareAndRightsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .link:
            return 5
        case .invite, .access:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 100
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .invite, .link:
            return 1
        case .access:
            if let sharedFile = sharedFile {
                return sharedFile.users.count + sharedFile.invitations.count + sharedFile.tags.count
            } else {
                return 0
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .invite:
            let cell = tableView.dequeueReusableCell(type: InviteUserTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.drive = driveFileManager?.drive
            cell.removeUsers = removeUsers
            cell.removeEmails = removeEmails
            cell.delegate = self
            return cell
        case .link:
            let cell = tableView.dequeueReusableCell(type: ShareLinkTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true, radius: 6)
            cell.delegate = self
            cell.configureWith(sharedFile: sharedFile, isOfficeFile: (file?.isOfficeFile ?? false), enabled: (file?.rights?.canBecomeLink.value ?? false) || file?.shareLink != nil)
            return cell
        case .access:
            let cell = tableView.dequeueReusableCell(type: UsersAccessTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == (self.tableView(tableView, numberOfRowsInSection: indexPath.section)) - 1, radius: 6)
            if indexPath.row < sharedFile!.tags.count {
                cell.configureWith(tag: (sharedFile!.tags[indexPath.row])!, drive: driveFileManager.drive)
            } else if indexPath.row < (sharedFile!.tags.count) + (sharedFile!.users.count) {
                let index = indexPath.row - (sharedFile!.tags.count)
                cell.configureWith(user: sharedFile!.users[index], blocked: AccountManager.instance.currentUserId == sharedFile!.users[index].id)
            } else {
                let index = indexPath.row - ((sharedFile!.tags.count) + (sharedFile!.users.count))
                cell.configureWith(invitation: (sharedFile!.invitations[index])!)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .invite:
            break
        case .link:
            break
        case .access:
            shareLinkRights = false
            selectedUserIndex = nil
            selectedTagIndex = nil
            selectedInvitationIndex = nil

            if indexPath.row < sharedFile!.tags.count {
                selectedTagIndex = indexPath.row
            } else if indexPath.row < (sharedFile!.tags.count) + (sharedFile!.users.count) {
                let index = indexPath.row - (sharedFile!.tags.count)
                if sharedFile!.users[index].id == AccountManager.instance.currentUserId {
                    break
                }
                selectedUserIndex = index
                let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController()
                rightsSelectionViewController.modalPresentationStyle = .fullScreen
                if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
                    rightsSelectionVC.driveFileManager = driveFileManager
                    rightsSelectionVC.delegate = self
                    rightsSelectionVC.selectedRight = sharedFile!.users[index].permission!.rawValue
                    rightsSelectionVC.user = sharedFile!.users[index]
                    rightsSelectionVC.userType = "user"
                }
                present(rightsSelectionViewController, animated: true)
            } else {
                let index = indexPath.row - ((sharedFile!.tags.count) + (sharedFile!.users.count))
                selectedInvitationIndex = index
                let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController()
                rightsSelectionViewController.modalPresentationStyle = .fullScreen
                if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
                    rightsSelectionVC.driveFileManager = driveFileManager
                    rightsSelectionVC.delegate = self
                    rightsSelectionVC.selectedRight = sharedFile!.invitations[index]!.permission.rawValue
                    rightsSelectionVC.invitation = sharedFile!.invitations[index]!
                    rightsSelectionVC.userType = "invitation"
                }
                present(rightsSelectionViewController, animated: true)
            }

        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .invite, .link:
            return nil
        case .access:
            return NewFolderSectionHeaderView.instantiate(title: KDriveStrings.Localizable.fileShareDetailsUsersAccesTitle)
        }
    }
}

// MARK: - RightsSelectionDelegate
extension ShareAndRightsViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        if let sharedLink = sharedFile?.link, shareLinkRights {
            driveFileManager.apiFetcher.updateShareLinkWith(file: file, canEdit: value == "write", permission: sharedLink.permission, date: sharedLink.validUntil != nil ? TimeInterval(sharedLink.validUntil!) : nil, blockDownloads: sharedLink.blockDownloads, blockComments: sharedLink.blockComments, blockInformation: sharedLink.blockInformation, isFree: driveFileManager.drive.pack == .free) { _, _ in

            }
        } else if let index = selectedUserIndex {
            driveFileManager.apiFetcher.updateUserRights(file: file, user: sharedFile!.users[index], permission: value) { response, _ in
                if response?.data != nil {
                    self.sharedFile!.users[index].permission = UserPermission(rawValue: value)
                    self.tableView.reloadRows(at: [IndexPath(row: index + self.sharedFile!.tags.count, section: 2)], with: .automatic)
                }
            }
        } else if let index = selectedInvitationIndex {
            driveFileManager.apiFetcher.updateInvitationRights(invitation: sharedFile!.invitations[index]!, permission: value) { response, _ in
                if response?.data != nil {
                    self.sharedFile!.invitations[index]!.permission = UserPermission(rawValue: value)!
                    self.tableView.reloadRows(at: [IndexPath(row: index + self.sharedFile!.tags.count + self.sharedFile!.users.count, section: 2)], with: .automatic)
                }
            }
        }
    }

    func didDeleteUserRight() {
        if let index = selectedUserIndex {
            driveFileManager.apiFetcher.deleteUserRights(file: file, user: sharedFile!.users[index]) { response, _ in
                if response?.data != nil {
                    self.tableView.reloadSections([0, 2], with: .automatic)
                }
            }
        } else if let index = selectedInvitationIndex {
            driveFileManager.apiFetcher.deleteInvitationRights(invitation: sharedFile!.invitations[index]!) { response, _ in
                if response?.data != nil {
                    self.tableView.reloadSections([0, 2], with: .automatic)
                }
            }
        }
    }
}

// MARK: - ShareLinkTableViewCellDelegate
extension ShareAndRightsViewController: ShareLinkTableViewCellDelegate {
    func shareLinkRightsButtonPressed() {
        guard let sharedLink = sharedFile?.link else {
            return
        }
        let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController()
        rightsSelectionViewController.modalPresentationStyle = .fullScreen
        if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
            rightsSelectionVC.driveFileManager = driveFileManager
            rightsSelectionVC.delegate = self
            rightsSelectionVC.rightSelectionType = .officeOnly
            rightsSelectionVC.selectedRight = sharedLink.canEdit ? "write" : "read"
        }
        shareLinkRights = true
        present(rightsSelectionViewController, animated: true)
    }

    func shareLinkSettingsButtonPressed() {
        let shareLinkSettingsViewController = ShareLinkSettingsViewController.instantiate()
        shareLinkSettingsViewController.driveFileManager = driveFileManager
        shareLinkSettingsViewController.file = file
        shareLinkSettingsViewController.shareFile = sharedFile
        navigationController?.pushViewController(shareLinkSettingsViewController, animated: true)
    }

    func shareLinkSwitchToggled(isOn: Bool) {
        if isOn {
            driveFileManager.activateShareLink(for: file) { _, shareLink, _ in
                if let link = shareLink {
                    self.sharedFile?.link = link
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .automatic)
                }
            }
        } else {
            driveFileManager.removeShareLink(for: file) { file, _ in
                if file != nil {
                    self.sharedFile?.link = nil
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .automatic)
                }
            }
        }
    }
}

// MARK: - SearchUserDelegate
extension ShareAndRightsViewController: SearchUserDelegate {
    func didSelectUser(user: DriveUser) {
        let inviteUserViewController = InviteUserViewController.instantiateInNavigationController()
        inviteUserViewController.modalPresentationStyle = .fullScreen
        if let inviteUserVC = inviteUserViewController.viewControllers.first as? InviteUserViewController {
            inviteUserVC.driveFileManager = driveFileManager
            inviteUserVC.users.append(user)
            inviteUserVC.file = file
            inviteUserVC.removeEmails = removeEmails
            inviteUserVC.removeUsers = removeUsers + [user.id]
        }
        present(inviteUserViewController, animated: true)
    }

    func didSelectMail(mail: String) {
        let inviteUserViewController = InviteUserViewController.instantiateInNavigationController()
        inviteUserViewController.modalPresentationStyle = .fullScreen
        if let inviteUserVC = inviteUserViewController.viewControllers.first as? InviteUserViewController {
            inviteUserVC.driveFileManager = driveFileManager
            inviteUserVC.emails.append(mail)
            inviteUserVC.file = file
            inviteUserVC.removeEmails = removeEmails + [mail]
            inviteUserVC.removeUsers = removeUsers
        }
        present(inviteUserViewController, animated: true)
    }
}
