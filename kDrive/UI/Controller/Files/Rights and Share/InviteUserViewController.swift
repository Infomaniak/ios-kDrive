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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class InviteUserViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var driveInfosManager: DriveInfosManager

    var file: File!
    var fileAccess: FileAccess!
    var driveFileManager: DriveFileManager!
    var ignoredEmails: [String] = []
    var ignoredShareables: [Shareable] = []
    var emails: [String] = []
    var shareables: [Shareable] = []

    var userIds: [Int] {
        return shareables.compactMap { $0 as? DriveUser }.map(\.id)
    }

    var teamIds: [Int] {
        return shareables.compactMap { $0 as? Team }.map(\.id)
    }

    private enum InviteUserSections: CaseIterable {
        case users
        case rights
        case message
    }

    private enum InviteUserRows: CaseIterable {
        case invited
        case addUser
    }

    private var sections = InviteUserSections.allCases
    private var rows = InviteUserRows.allCases
    private var newPermission = UserPermission.read
    private var message: String?
    private var emptyInvitation = false
    private var savedText = String()
    private var searchControllerManager: SearchControllerManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: InviteUserTableViewCell.self)
        tableView.register(cellView: MenuTableViewCell.self)
        tableView.register(cellView: MessageTableViewCell.self)
        tableView.register(cellView: InvitedUserTableViewCell.self)

        hideKeyboardWhenTappedAround()
        setTitle()
        tableView.sectionHeaderHeight = 0

        searchControllerManager = SearchControllerManager()
        searchControllerManager.setup(in: self, tableView: tableView, file: file, driveFileManager: driveFileManager,
                                      ignoredShareables: ignoredShareables, ignoredEmails: ignoredEmails)
        searchControllerManager.delegate = self

        reloadInvited()

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonPressed)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: [MatomoUtils.View.shareAndRights.displayName, "InviteUser"])
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
        navigationItem.title = file.isDirectory ? KDriveResourcesStrings.Localizable.fileShareFolderTitle : KDriveResourcesStrings
            .Localizable.fileShareFileTitle
    }

    func showConflictDialog(conflictList: [CheckChangeAccessFeedbackResource]) {
        let message: NSMutableAttributedString
        if conflictList.count == 1, let user = fileAccess.users.first(where: { $0.id == conflictList[0].userId }) {
            message = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable
                    .sharedConflictDescription(user.name, user.right.title, newPermission.title),
                boldText: user.name
            )
        } else {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable
                .sharedConflictManyUserDescription(newPermission.title))
        }
        let alert = AlertTextViewController(
            title: KDriveResourcesStrings.Localizable.sharedConflictTitle,
            message: message,
            action: KDriveResourcesStrings.Localizable.buttonShare
        ) {
            self.shareAndDismiss()
        }
        present(alert, animated: true)
    }

    func shareAndDismiss() {
        let settings = FileAccessSettings(
            message: message,
            right: newPermission,
            emails: emails,
            teamIds: teamIds,
            userIds: userIds
        )
        Task { [proxyFile = file.proxify()] in
            _ = try await driveFileManager.apiFetcher.addAccess(to: proxyFile, settings: settings)
        }
        dismiss(animated: true)
    }

    func reloadInvited() {
        // Save text to reassign it after reload
        if let addUserIndex = rows.firstIndex(of: .addUser) {
            let cell = tableView.cellForRow(at: IndexPath(row: addUserIndex, section: 0)) as? InviteUserTableViewCell
            savedText = cell?.textField.text ?? ""
        }

        emptyInvitation = emails.isEmpty && userIds.isEmpty && teamIds.isEmpty

        if emptyInvitation {
            rows = [.addUser]
            searchControllerManager.addUserCellIndex = IndexPath(row: 0, section: 0)
        } else {
            rows = [.invited, .addUser]
            searchControllerManager.addUserCellIndex = IndexPath(row: 1, section: 0)
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
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension InviteUserViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sections[section] == .users {
            return rows.count
        } else {
            return 1
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .message:
            return 180
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .users:
            switch rows[indexPath.row] {
            case .invited:
                let cell = tableView.dequeueReusableCell(type: InvitedUserTableViewCell.self, for: indexPath)
                cell.configureWith(shareables: shareables, emails: emails, tableViewWidth: tableView.bounds.width)
                cell.delegate = self
                cell.selectionStyle = .none
                return cell

            case .addUser:
                let cell = tableView.dequeueReusableCell(type: InviteUserTableViewCell.self, for: indexPath)
                cell.delegate = searchControllerManager
                cell.transform = .identity
                return cell
            }

        case .rights:
            let cell = tableView.dequeueReusableCell(type: MenuTableViewCell.self, for: indexPath)
            cell.logoImage.tintColor = KDriveResourcesAsset.iconColor.color
            (cell.titleLabel as? IKLabel)?.style = .header3
            cell.selectionStyle = .none
            cell.titleLabel.text = newPermission.title
            cell.logoImage?.image = newPermission.icon
            cell.logoImage.isAccessibilityElement = false
            return cell

        case .message:
            let cell = tableView.dequeueReusableCell(type: MessageTableViewCell.self, for: indexPath)
            if let message, !message.isEmpty {
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
        switch sections[indexPath.section] {
        case .rights:
            let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController(
                file: file,
                driveFileManager: driveFileManager
            )
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
        if section == sections.count - 1 {
            return 124
        } else {
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 {
            let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonShare)
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
        searchControllerManager.searchUserViewController.ignoredShareables = ignoredShareables
        searchControllerManager.searchController.isActive = false
    }

    func didSelect(email: String) {
        emails.append(email)
        ignoredEmails.append(email)
        reloadInvited()
        searchControllerManager.searchUserViewController.ignoredEmails = ignoredEmails
        searchControllerManager.searchController.isActive = false
    }
}

// MARK: - Selected users delegate

extension InviteUserViewController: SelectedUsersDelegate {
    func didDelete(shareable: Shareable) {
        shareables.removeAll { $0.id == shareable.id }
        ignoredShareables.removeAll { $0.id == shareable.id }
        searchControllerManager.searchUserViewController.ignoredShareables = ignoredShareables
        reloadInvited()
    }

    func didDelete(email: String) {
        emails.removeAll { $0 == email }
        ignoredEmails.removeAll { $0 == email }
        searchControllerManager.searchUserViewController.ignoredEmails = ignoredEmails
        reloadInvited()
    }
}

// MARK: - Rights selection delegate

extension InviteUserViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        newPermission = UserPermission(rawValue: value)!
        if let index = sections.firstIndex(of: .rights) {
            tableView.reloadRows(at: [IndexPath(row: 0, section: index)], with: .automatic)
        }
    }
}

extension InviteUserViewController: FooterButtonDelegate {
    func didClickOnButton(_ sender: IKLargeButton) {
        matomo.track(eventWithCategory: .shareAndRights, name: "inviteUser")
        tableView.isUserInteractionEnabled = false
        sender.setLoading(true)

        let settings = FileAccessSettings(
            message: message,
            right: newPermission,
            emails: emails,
            teamIds: teamIds,
            userIds: userIds
        )
        Task { [proxyFile = file.proxify()] in
            defer {
                tableView.isUserInteractionEnabled = true
                sender.setLoading(false)
            }

            let results = try await driveFileManager.apiFetcher.checkAccessChange(to: proxyFile, settings: settings)
            let conflictList = results.filter { !$0.needChange }
            if conflictList.isEmpty {
                self.shareAndDismiss()
            } else {
                self.showConflictDialog(conflictList: conflictList)
            }
        }
    }
}
