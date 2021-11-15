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
import UIKit

class InviteUserViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    var file: File!
    var sharedFile: SharedFile!
    var driveFileManager: DriveFileManager!
    var ignoredShareables: [Shareable] = []
    var ignoredEmails: [String] = []
    var emails: [String] = []
    var shareables: [Shareable] = []

    private enum InviteUserRows: CaseIterable {
        case invited
        case addUser
        case rights
        case message
    }

    private var rows = InviteUserRows.allCases
    private var newPermission = UserPermission.read
    private var message = String()
    private var emptyInvitation = false
    private var savedText = String()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: InviteUserTableViewCell.self)
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: MessageTableViewCell.self)
        tableView.register(cellView: InvitedUserTableViewCell.self)

        hideKeyboardWhenTappedAround()
        setTitle()
        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset.bottom = keyboardSize.height

            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        UIView.animate(withDuration: 0.1) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true)
    }

    func setTitle() {
        guard file != nil else { return }
        navigationItem.title = file.isDirectory ? KDriveStrings.Localizable.fileShareFolderTitle : KDriveStrings.Localizable.fileShareFileTitle
    }

    func showConflictDialog(conflictList: [FileCheckResult]) {
        let message: NSMutableAttributedString
        if conflictList.count == 1, let user = sharedFile.users.first(where: { $0.id == conflictList[0].userId }) {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.sharedConflictDescription(user.displayName, (user.permission ?? .read).title, newPermission.title), boldText: user.displayName)
        } else {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.sharedConflictManyUserDescription(newPermission.title))
        }
        let alert = AlertTextViewController(title: KDriveStrings.Localizable.sharedConflictTitle, message: message, action: KDriveStrings.Localizable.buttonShare) {
            self.shareAndDismiss()
        }
        present(alert, animated: true)
    }

    func shareAndDismiss() {
        let usersIds = shareables.compactMap { $0 as? DriveUser }.map(\.id)
        let teams = shareables.compactMap { $0 as? Team }.map(\.id)
        driveFileManager.apiFetcher.addUserRights(file: file, users: usersIds, teams: teams, emails: emails, message: message, permission: newPermission.rawValue) { _, _ in }
        dismiss(animated: true)
    }

    func reloadInvited() {
        // Save text to reassign it after reload
        if let addUserIndex = rows.firstIndex(of: .addUser) {
            let cell = tableView.cellForRow(at: IndexPath(row: addUserIndex, section: 0)) as? InviteUserTableViewCell
            savedText = cell?.textField.text ?? ""
        }

        emptyInvitation = shareables.isEmpty && emails.isEmpty

        if emptyInvitation {
            rows = [.addUser, .rights, .message]
        } else {
            rows = [.invited, .addUser, .rights, .message]
        }

        tableView.reloadSections([0], with: .automatic)
    }

    class func instantiateInNavigationController() -> TitleSizeAdjustingNavigationController {
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: instantiate())
        navigationController.restorationIdentifier = "InviteUserNavigationController"
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    class func instantiate() -> InviteUserViewController {
        return Storyboard.files.instantiateViewController(withIdentifier: "InviteUserViewController") as! InviteUserViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(file.id, forKey: "FileId")
        coder.encode(emails, forKey: "Emails")
        coder.encode(shareables.compactMap { $0 as? DriveUser }.map(\.id), forKey: "UserIds")
        coder.encode(shareables.compactMap { $0 as? Team }.map(\.id), forKey: "TeamIds")
        coder.encode(newPermission.rawValue, forKey: "NewPermission")
        coder.encode(message, forKey: "Message")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let fileId = coder.decodeInteger(forKey: "FileId")
        emails = coder.decodeObject(forKey: "Emails") as? [String] ?? []
        let userIds = coder.decodeObject(forKey: "UserIds") as? [Int] ?? []
        let teamIds = coder.decodeObject(forKey: "TeamIds") as? [Int] ?? []
        newPermission = UserPermission(rawValue: coder.decodeObject(forKey: "NewPermission") as? String ?? "") ?? .read
        message = coder.decodeObject(forKey: "Message") as? String ?? ""
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        file = driveFileManager.getCachedFile(id: fileId)
        let realm = DriveInfosManager.instance.getRealm()
        shareables = userIds.compactMap { DriveInfosManager.instance.getUser(id: $0, using: realm) } + teamIds.compactMap { DriveInfosManager.instance.getTeam(id: $0, using: realm) }
        // Update UI
        setTitle()
        reloadInvited()
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension InviteUserViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch rows[indexPath.row] {
        case .invited:
            return UITableView.automaticDimension
        case .message:
            return 180
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .invited:
            let cell = tableView.dequeueReusableCell(type: InvitedUserTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: false)
            cell.configureWith(shareables: shareables, emails: emails, tableViewWidth: tableView.bounds.width)
            cell.delegate = self
            cell.selectionStyle = .none
            return cell
        case .addUser:
            let cell = tableView.dequeueReusableCell(type: InviteUserTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: emptyInvitation, isLast: true)
            cell.canUseTeam = sharedFile.canUseTeam
            cell.drive = driveFileManager.drive
            cell.textField.text = savedText
            cell.textField.placeholder = KDriveStrings.Localizable.shareFileInputUserAndEmail
            cell.ignoredShareables = ignoredShareables
            cell.ignoredEmails = ignoredEmails
            cell.delegate = self
            return cell
        case .rights:
            let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.logoImage.tintColor = KDriveAsset.iconColor.color
            (cell.titleLabel as? IKLabel)?.style = .header3
            cell.selectionStyle = .none
            cell.titleLabel.text = newPermission.title
            cell.logoImage?.image = newPermission.icon
            return cell
        case .message:
            let cell = tableView.dequeueReusableCell(type: MessageTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            if !message.isEmpty {
                cell.messageTextView.text = message
            }
            cell.selectionStyle = .none
            cell.textDidChange = { [weak self] text in
                self?.message = text
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch rows[indexPath.row] {
        case .addUser:
            break
        case .rights:
            let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController(file: file, driveFileManager: driveFileManager)
            rightsSelectionViewController.modalPresentationStyle = .fullScreen
            if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
                rightsSelectionVC.delegate = self
                rightsSelectionVC.selectedRight = newPermission.rawValue
                rightsSelectionVC.canDelete = false
            }
            present(rightsSelectionViewController, animated: true)
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 124
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 {
            let view = FooterButtonView.instantiate(title: KDriveStrings.Localizable.buttonShare)
            view.delegate = self
            return view
        }
        return nil
    }
}

// MARK: - Search user delegate

extension InviteUserViewController: SearchUserDelegate {
    func didSelect(shareable: Shareable) {
        shareables.append(shareable)
        ignoredShareables.append(shareable)
        reloadInvited()
    }

    func didSelect(email: String) {
        emails.append(email)
        ignoredEmails.append(email)
        reloadInvited()
    }
}

// MARK: - Selected users delegate

extension InviteUserViewController: SelectedUsersDelegate {
    func didDelete(shareable: Shareable) {
        shareables.removeAll { $0.id == shareable.id }
        ignoredShareables.removeAll { $0.id == shareable.id }
        reloadInvited()
    }

    func didDelete(email: String) {
        emails.removeAll { $0 == email }
        ignoredEmails.removeAll { $0 == email }
        reloadInvited()
    }
}

// MARK: - Rights selection delegate

extension InviteUserViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        newPermission = UserPermission(rawValue: value)!
        if let index = rows.firstIndex(of: .rights) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }
}

extension InviteUserViewController: FooterButtonDelegate {
    func didClickOnButton() {
        let usersIds = shareables.compactMap { $0 as? DriveUser }.map(\.id)
        let teams = shareables.compactMap { $0 as? Team }.map(\.id)
        driveFileManager.apiFetcher.checkUserRights(file: file, users: usersIds, teams: teams, emails: emails, permission: newPermission.rawValue) { response, _ in
            let conflictList = response?.data?.filter(\.isConflict) ?? []
            if conflictList.isEmpty {
                self.shareAndDismiss()
            } else {
                self.showConflictDialog(conflictList: conflictList)
            }
        }
    }
}
