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

import CocoaLumberjackSwift
import DropDown
import kDriveCore
import kDriveResources
import UIKit

class ShareAndRightsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    private enum ShareAndRightsSections: CaseIterable {
        case invite
        case link
        case access
    }

    private let sections = ShareAndRightsSections.allCases

    private var shareLinkIsActive = false
    private var ignoredEmails: [String] = []
    private var shareLinkRights = false
    private var initialLoading = true
    private var sharedFile: SharedFile?
    private var shareLink: ShareLink?
    private var shareables: [Shareable] = []
    private var selectedShareable: Shareable?

    var driveFileManager: DriveFileManager!
    var file: File!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Documentation says it's better to put it in AppDelegate but why ?
        DropDown.startListeningToKeyboard()

        navigationController?.navigationBar.isTranslucent = true

        navigationItem.hideBackButtonText()

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
        MatomoUtils.track(view: [MatomoUtils.Views.shareAndRights.displayName])
    }

    private func setTitle() {
        guard file != nil else { return }
        title = file.isDirectory ? KDriveResourcesStrings.Localizable.fileShareDetailsFolderTitle(file.name) : KDriveResourcesStrings.Localizable.fileShareDetailsFileTitle(file.name)
    }

    private func updateShareList() {
        driveFileManager?.apiFetcher.getShareListFor(file: file) { response, error in
            if let sharedFile = response?.data {
                self.sharedFile = sharedFile
                self.shareables = sharedFile.shareables
                self.ignoredEmails = sharedFile.invitations.compactMap { $0?.userId != nil ? nil : $0?.email }
                self.tableView.reloadData()
            } else {
                if let error = response?.error ?? error {
                    DDLogError("Cannot get shared file: \(error)")
                } else {
                    DDLogError("Cannot get shared file (unknown error)")
                }
            }
        }
        Task {
            self.shareLink = try? await driveFileManager?.apiFetcher.shareLink(for: file)
        }
    }

    private func showRightsSelection(userAccess: Bool) {
        let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController(file: file, driveFileManager: driveFileManager)
        rightsSelectionViewController.modalPresentationStyle = .fullScreen
        if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
            rightsSelectionVC.delegate = self
            if userAccess {
                guard let shareable = selectedShareable else { return }

                rightsSelectionVC.selectedRight = (shareable.right ?? .read).rawValue
                rightsSelectionVC.shareable = shareable
            } else {
                rightsSelectionVC.selectedRight = (shareLink == nil ? ShareLinkPermission.restricted : ShareLinkPermission.public).rawValue
                rightsSelectionVC.rightSelectionType = .shareLinkSettings
            }
        }
        present(rightsSelectionViewController, animated: true)
    }

    private func showInviteView(shareables: [Shareable] = [], emails: [String] = []) {
        let inviteUserViewController = InviteUserViewController.instantiateInNavigationController()
        inviteUserViewController.modalPresentationStyle = .fullScreen
        if let inviteUserVC = inviteUserViewController.viewControllers.first as? InviteUserViewController {
            inviteUserVC.driveFileManager = driveFileManager
            inviteUserVC.file = file
            inviteUserVC.sharedFile = sharedFile
            inviteUserVC.shareables = shareables
            inviteUserVC.emails = emails
            inviteUserVC.ignoredEmails = ignoredEmails + emails
            inviteUserVC.ignoredShareables = self.shareables + shareables
        }
        present(inviteUserViewController, animated: true)
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }

    class func instantiate(driveFileManager: DriveFileManager, file: File) -> ShareAndRightsViewController {
        let viewController = Storyboard.files.instantiateViewController(withIdentifier: "ShareAndRightsViewController") as! ShareAndRightsViewController
        viewController.driveFileManager = driveFileManager
        viewController.file = file
        return viewController
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
        updateShareList()
    }
}

// MARK: - Table view delegate & data source

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
            return shareables.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .invite:
            let cell = tableView.dequeueReusableCell(type: InviteUserTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            // cell.canUseTeam = sharedFile?.canUseTeam ?? false
            cell.drive = driveFileManager?.drive
            cell.ignoredShareables = shareables
            cell.ignoredEmails = ignoredEmails
            cell.delegate = self
            return cell
        case .link:
            let cell = tableView.dequeueReusableCell(type: ShareLinkTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true, radius: 6)
            cell.delegate = self
            cell.configureWith(shareLink: shareLink, file: file)
            return cell
        case .access:
            let cell = tableView.dequeueReusableCell(type: UsersAccessTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1, radius: 6)
            cell.configure(with: shareables[indexPath.row], drive: driveFileManager.drive)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .invite:
            break
        case .link:
            let canBecomeLink = file?.rights?.canBecomeLink ?? false || file.shareLink != nil
            if file.visibility == .isCollaborativeFolder || !canBecomeLink {
                return
            }
            shareLinkRights = true
            showRightsSelection(userAccess: false)
        case .access:
            shareLinkRights = false
            selectedShareable = shareables[indexPath.row]
            if let user = selectedShareable as? DriveUser, user.id == driveFileManager.drive.userId {
                break
            }
            showRightsSelection(userAccess: true)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .invite, .link:
            return nil
        case .access:
            return NewFolderSectionHeaderView.instantiate(title: KDriveResourcesStrings.Localizable.fileShareDetailsUsersAccesTitle)
        }
    }
}

// MARK: - Rights selection delegate

extension ShareAndRightsViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        if shareLinkRights {
            let right = ShareLinkPermission(rawValue: value)!
            Task {
                do {
                    let response: Bool
                    if right == .restricted {
                        // Remove share link
                        response = try await driveFileManager.removeShareLink(for: file)
                        if response {
                            self.shareLink = nil
                        }
                    } else {
                        // Update share link
                        response = try await driveFileManager.apiFetcher.updateShareLink(for: file, settings: .init(canComment: shareLink?.capabilities.canComment, canDownload: shareLink?.capabilities.canDownload, canEdit: shareLink?.capabilities.canEdit, canSeeInfo: shareLink?.capabilities.canSeeInfo, canSeeStats: shareLink?.capabilities.canSeeStats, right: right, validUntil: shareLink?.validUntil))
                    }
                    if response {
                        self.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .automatic)
                    }
                } catch {
                    UIConstants.showSnackBar(message: error.localizedDescription)
                }
            }
        } else {
            if let user = selectedShareable as? DriveUser {
                driveFileManager.apiFetcher.updateUserRights(file: file, user: user, permission: value) { response, _ in
                    if response?.data != nil {
                        user.permission = UserPermission(rawValue: value)
                        if let index = self.shareables.firstIndex(where: { $0.id == user.id }) {
                            self.tableView.reloadRows(at: [IndexPath(row: index, section: 2)], with: .automatic)
                        }
                    }
                }
            } else if let invitation = selectedShareable as? Invitation {
                driveFileManager.apiFetcher.updateInvitationRights(driveId: driveFileManager.drive.id, invitation: invitation, permission: value) { response, _ in
                    if response?.data != nil {
                        invitation.permission = UserPermission(rawValue: value)!
                        if let index = self.shareables.firstIndex(where: { $0.id == invitation.id }) {
                            self.tableView.reloadRows(at: [IndexPath(row: index, section: 2)], with: .automatic)
                        }
                    }
                }
            } else if let team = selectedShareable as? Team {
                driveFileManager.apiFetcher.updateTeamRights(file: file, team: team, permission: value) { response, _ in
                    if response?.data != nil {
                        team.right = UserPermission(rawValue: value)
                        if let index = self.shareables.firstIndex(where: { $0.id == team.id }) {
                            self.tableView.reloadRows(at: [IndexPath(row: index, section: 2)], with: .automatic)
                        }
                    }
                }
            }
        }
    }

    func didDeleteUserRight() {
        if let user = selectedShareable as? DriveUser {
            driveFileManager.apiFetcher.deleteUserRights(file: file, user: user) { response, _ in
                if response?.data != nil {
                    self.tableView.reloadSections([0, 2], with: .automatic)
                }
            }
        } else if let invitation = selectedShareable as? Invitation {
            driveFileManager.apiFetcher.deleteInvitationRights(driveId: driveFileManager.drive.id, invitation: invitation) { response, _ in
                if response?.data != nil {
                    self.tableView.reloadSections([0, 2], with: .automatic)
                }
            }
        } else if let team = selectedShareable as? Team {
            driveFileManager.apiFetcher.deleteTeamRights(file: file, team: team) { response, _ in
                if response?.data != nil {
                    self.tableView.reloadSections([0, 2], with: .automatic)
                }
            }
        }
    }
}

// MARK: - Share link table view cell delegate

extension ShareAndRightsViewController: ShareLinkTableViewCellDelegate {
    func shareLinkSharedButtonPressed(link: String, sender: UIView) {
        let items = [URL(string: link)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = sender
        present(ac, animated: true)
    }

    func shareLinkSettingsButtonPressed() {
        let shareLinkSettingsViewController = ShareLinkSettingsViewController.instantiate()
        shareLinkSettingsViewController.driveFileManager = driveFileManager
        shareLinkSettingsViewController.file = file
        shareLinkSettingsViewController.shareLink = shareLink
        navigationController?.pushViewController(shareLinkSettingsViewController, animated: true)
    }
}

// MARK: - Search user delegate

extension ShareAndRightsViewController: SearchUserDelegate {
    func didSelect(shareable: Shareable) {
        showInviteView(shareables: [shareable])
    }

    func didSelect(email: String) {
        showInviteView(emails: [email])
    }
}
