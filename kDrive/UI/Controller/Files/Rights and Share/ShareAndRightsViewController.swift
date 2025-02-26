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
import InfomaniakDI
import kDriveCore
import kDriveResources
import LinkPresentation
import UIKit

class ShareAndRightsViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    @LazyInjectService var router: AppNavigable
    @LazyInjectService var accountManager: AccountManageable

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
    private var fileAccess: FileAccess?
    private var fileAccessElements = [FileAccessElement]()
    private var selectedElement: FileAccessElement?

    var driveFileManager: DriveFileManager!
    var file: File!

    lazy var packId = DrivePackId(rawValue: driveFileManager.drive.pack.name)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Documentation says it's better to put it in AppDelegate but why ?
        DropDown.startListeningToKeyboard()

        navigationController?.navigationBar.isTranslucent = true

        navigationItem.hideBackButtonText()

        tableView.register(cellView: InviteUserTableViewCell.self)
        tableView.register(cellView: UsersAccessTableViewCell.self)
        tableView.register(cellView: ShareLinkTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)

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
        title = file.isDirectory ? KDriveResourcesStrings.Localizable
            .fileShareDetailsFolderTitle(file.name) : KDriveResourcesStrings.Localizable.fileShareDetailsFileTitle(file.name)
    }

    private func updateShareList() {
        guard driveFileManager != nil else { return }
        Task { [fileProxy = file.proxify()] in
            do {
                let fetchedAccess = try await driveFileManager.apiFetcher.access(for: fileProxy)
                self.fileAccess = fetchedAccess
                self.fileAccessElements = fetchedAccess.elements
                self.ignoredEmails = fetchedAccess.invitations.compactMap { $0.user != nil ? nil : $0.email }
                self.tableView.reloadData()
            } catch {
                DDLogError("Cannot get file access: \(error)")
            }
        }
    }

    private func showRightsSelection(userAccess: Bool) {
        let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController(file: file,
                                                                                                            driveFileManager: driveFileManager)
        rightsSelectionViewController.modalPresentationStyle = .fullScreen
        if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
            rightsSelectionVC.delegate = self
            if userAccess {
                guard let element = selectedElement else { return }

                rightsSelectionVC.selectedRight = element.right.rawValue
                rightsSelectionVC.fileAccessElement = element
            } else {
                rightsSelectionVC
                    .selectedRight = (file.hasSharelink ? ShareLinkPermission.public : ShareLinkPermission.restricted).rawValue
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
            inviteUserVC.fileAccess = fileAccess
            inviteUserVC.shareables = shareables
            inviteUserVC.emails = emails
            inviteUserVC.ignoredEmails = ignoredEmails + emails
            inviteUserVC.ignoredShareables = fileAccessElements.compactMap(\.shareable) + shareables
        }
        present(inviteUserViewController, animated: true)
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        _ = navigationController?.popViewController(animated: true)
    }

    class func instantiate(driveFileManager: DriveFileManager, file: File) -> ShareAndRightsViewController {
        let viewController = Storyboard.files
            .instantiateViewController(withIdentifier: "ShareAndRightsViewController") as! ShareAndRightsViewController
        viewController.driveFileManager = driveFileManager
        viewController.file = file
        return viewController
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
            return fileAccessElements.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .invite:
            let cell = tableView.dequeueReusableCell(type: InviteUserTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.canUseTeam = file.capabilities.canUseTeam
            cell.drive = driveFileManager?.drive
            cell.ignoredShareables = fileAccessElements.compactMap(\.shareable)
            cell.ignoredEmails = ignoredEmails
            cell.delegate = self
            return cell
        case .link:
            let cell = tableView.dequeueReusableCell(type: ShareLinkTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true, radius: 6)
            cell.delegate = self
            cell.configureWith(file: file, currentPackId: packId, driveFileManager: driveFileManager)
            return cell
        case .access:
            let cell = tableView.dequeueReusableCell(type: UsersAccessTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(
                isFirst: indexPath.row == 0,
                isLast: indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1,
                radius: 6
            )
            cell.configure(with: fileAccessElements[indexPath.row], drive: driveFileManager.drive)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .invite:
            break
        case .link:
            guard !showMykSuiteRestriction(fileHasShareLink: file.hasSharelink) else {
                router.presentUpSaleSheet()
                MatomoUtils.track(eventWithCategory: .myKSuiteUpgradeBottomSheet, name: "shareLinkQuotaExceeded")
                return
            }

            let canBecomeLink = file?.capabilities.canBecomeSharelink ?? false || file.hasSharelink
            if file.isDropbox || !canBecomeLink {
                return
            }
            shareLinkRights = true
            showRightsSelection(userAccess: false)
        case .access:
            shareLinkRights = false
            selectedElement = fileAccessElements[indexPath.row]
            if let user = selectedElement as? UserFileAccess, user.id == driveFileManager.drive.userId {
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
            return NewFolderSectionHeaderView
                .instantiate(title: KDriveResourcesStrings.Localizable.fileShareDetailsUsersAccesTitle)
        }
    }

    private func showMykSuiteRestriction(fileHasShareLink: Bool) -> Bool {
        return MykSuiteRestrictions.sharedLinkRestricted(packId: packId,
                                                         driveFileManager: driveFileManager,
                                                         fileHasShareLink: fileHasShareLink)
    }
}

// MARK: - Rights selection delegate

extension ShareAndRightsViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        if shareLinkRights {
            let right = ShareLinkPermission(rawValue: value)!
            Task { [proxyFile = file.proxify()] in
                do {
                    try await driveFileManager.createOrRemoveShareLink(for: proxyFile, right: right)
                    self.tableView.reloadRows(at: [IndexPath(row: 1, section: 1)], with: .automatic)
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        } else {
            Task { [proxyFile = file.proxify()] in
                do {
                    let right = UserPermission(rawValue: value)!
                    var response = false
                    if let user = selectedElement as? UserFileAccess {
                        response = try await driveFileManager.apiFetcher.updateUserAccess(to: proxyFile, user: user, right: right)
                    } else if let invitation = selectedElement as? ExternInvitationFileAccess {
                        response = try await driveFileManager.apiFetcher.updateInvitationAccess(
                            drive: driveFileManager.drive,
                            invitation: invitation,
                            right: right
                        )
                    } else if let team = selectedElement as? TeamFileAccess {
                        response = try await driveFileManager.apiFetcher.updateTeamAccess(to: proxyFile, team: team, right: right)
                    }
                    if response {
                        selectedElement?.right = right
                        if let index = self.fileAccessElements.firstIndex(where: { $0.id == selectedElement?.id }) {
                            self.tableView.reloadRows(at: [IndexPath(row: index, section: 2)], with: .automatic)
                        }
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        }
    }

    func didDeleteUserRight() {
        Task { [proxyFile = file.proxify()] in
            do {
                var response = false
                if let user = selectedElement as? UserFileAccess {
                    response = try await driveFileManager.apiFetcher.removeUserAccess(to: proxyFile, user: user)
                } else if let invitation = selectedElement as? ExternInvitationFileAccess {
                    response = try await driveFileManager.apiFetcher.deleteInvitation(
                        drive: driveFileManager.drive,
                        invitation: invitation
                    )
                } else if let team = selectedElement as? TeamFileAccess {
                    response = try await driveFileManager.apiFetcher.removeTeamAccess(to: proxyFile, team: team)
                }
                if response {
                    self.tableView.reloadSections([0, 2], with: .automatic)
                }
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
    }
}

// MARK: - Share link table view cell delegate

extension ShareAndRightsViewController: ShareLinkTableViewCellDelegate {
    func shareLinkSharedButtonPressed(link: String, sender: UIView) {
        UIConstants.presentLinkPreviewForFile(file, link: link, from: self, sourceView: sender)
    }

    func shareLinkSettingsButtonPressed() {
        if packId == .myKSuite, driveFileManager.drive.sharedLinkQuotaExceeded {
            router.presentUpSaleSheet()
            MatomoUtils.track(eventWithCategory: .myKSuiteUpgradeBottomSheet, name: "shareLinkQuotaExceeded")
            return
        }

        let shareLinkSettingsViewController = ShareLinkSettingsViewController.instantiate()
        shareLinkSettingsViewController.driveFileManager = driveFileManager
        shareLinkSettingsViewController.file = file
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
