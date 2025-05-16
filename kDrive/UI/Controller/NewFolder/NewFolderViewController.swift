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
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

enum FolderType {
    case folder
    case commonFolder
    case dropbox
}

class NewFolderViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    @LazyInjectService private var matomo: MatomoUtils

    var folderType = FolderType.folder
    var driveFileManager: DriveFileManager!
    var currentDirectory: File!
    var newFolderName = ""
    var folderCreated = false
    var dropBoxUrl: String?
    var folderName: String?

    private var fileAccess: FileAccess?
    private var showSettings = false
    private var settings: [OptionsRow: Bool] = [
        .optionMail: true,
        .optionPassword: false,
        .optionDate: false,
        .optionSize: false
    ]
    private var settingsValue: [OptionsRow: Any?] = [
        .optionPassword: nil,
        .optionDate: nil,
        .optionSize: nil
    ]
    private var enableButton = false {
        didSet {
            guard let footer = tableView.footerView(forSection: tableView.numberOfSections - 1) as? FooterButtonView else {
                return
            }
            footer.footerButton.isEnabled = enableButton
        }
    }

    private var permissionSelection: Bool {
        return currentDirectory?.capabilities.canShare == true
    }

    private enum Section: CaseIterable {
        case header, permissions, options, location
    }

    private enum PermissionsRow: CaseIterable {
        case meOnly, allUsers, someUser, parentsRights
    }

    private enum OptionsRow: CaseIterable {
        case header, optionMail, optionPassword, optionDate, optionSize
    }

    private var sections: [Section] = [.header]
    private var permissionsRows = PermissionsRow.allCases
    private var optionsRows: [OptionsRow] = [.header]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(cellView: NewFolderHeaderTableViewCell.self)
        tableView.register(cellView: NewFolderShareRuleTableViewCell.self)
        tableView.register(cellView: NewFolderLocationTableViewCell.self)
        tableView.register(cellView: NewFolderSettingsTitleTableViewCell.self)
        tableView.register(cellView: NewFolderSettingsTableViewCell.self)
        tableView.contentInset.bottom = 60
        tableView.separatorColor = .clear
        hideKeyboardWhenTappedAround()

        navigationItem.backButtonTitle = KDriveResourcesStrings.Localizable.createFolderTitle
        navigationItem.hideBackButtonText()

        fetchAccessIfNeeded()
        setupTableViewRows()
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

    func fetchAccessIfNeeded() {
        guard currentDirectory.visibility != .isInSharedSpace else { return }

        Task { [proxyCurrentDirectory = currentDirectory.proxify()] in
            self.fileAccess = try? await driveFileManager.apiFetcher.access(for: proxyCurrentDirectory)
            self.setupTableViewRows()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if folderCreated {
            if let url = dropBoxUrl, let folderName {
                showDropBoxLink(url: url, fileName: folderName)
            } else {
                dismissAndRefreshDataSource()
            }
        }
        matomo.track(view: ["NewFolder"])
    }

    private func setupTableViewRows() {
        switch folderType {
        case .folder:
            sections = [.header]
            if permissionSelection {
                sections.append(.permissions)
                permissionsRows = [.meOnly]
                if let fileAccess {
                    permissionsRows.append(canInherit(fileAccess: fileAccess) ? .parentsRights : .someUser)
                }
            }
        case .commonFolder:
            sections = [.header, .permissions, .location]
            permissionsRows = [.allUsers, .someUser]
        case .dropbox:
            sections = [.header, .permissions, .options]
            permissionsRows = [.meOnly]
            if let fileAccess {
                permissionsRows.append(canInherit(fileAccess: fileAccess) ? .parentsRights : .someUser)
            }
        }
        tableView.reloadData()
    }

    private func canInherit(fileAccess: FileAccess) -> Bool {
        return fileAccess.users.count > 1 || !fileAccess.teams.isEmpty
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
        tableView.contentInset.bottom = 60
        UIView.animate(withDuration: 0.1) {
            self.view.layoutIfNeeded()
        }
    }

    func showDropBoxLink(url: String, fileName: String) {
        let driveFloatingPanelController = ShareFloatingPanelViewController.instantiatePanel()
        let floatingPanelViewController = driveFloatingPanelController.contentViewController as? ShareFloatingPanelViewController
        floatingPanelViewController?.copyTextField.text = url
        floatingPanelViewController?.titleLabel.text = KDriveResourcesStrings.Localizable.dropBoxResultTitle(fileName)
        let viewController = presentingViewController
        dismiss(animated: true) {
            viewController?.present(driveFloatingPanelController, animated: true)
        }
    }

    private func getSetting(for option: OptionsRow) -> Bool {
        return settings[option] ?? false
    }

    private func getValue(for option: OptionsRow) -> Any? {
        return settingsValue[option] ?? nil
    }

    func dismissAndRefreshDataSource() {
        if presentingViewController != nil {
            // Modal
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    func updateButton() {
        var activateButton = true
        activateButton = !newFolderName.isEmpty
        if folderType == .dropbox {
            for (option, enabled) in settings {
                if option != .optionMail && enabled && getValue(for: option) == nil {
                    activateButton = false
                }
            }
        }
        enableButton = activateButton && (tableView.indexPathForSelectedRow != nil || !permissionSelection)
    }
}

// MARK: - TextField and Keyboard Methods

extension NewFolderViewController: NewFolderTextFieldDelegate {
    func textFieldUpdated(content: String) {
        newFolderName = content.trimmingCharacters(in: .whitespacesAndNewlines)
        updateButton()
    }
}

// MARK: - NewFolderSettingsDelegate

extension NewFolderViewController: NewFolderSettingsDelegate {
    func didUpdateSettings(index: Int, isOn: Bool) {
        let option = optionsRows[index + 1]
        settings[option] = isOn
        tableView.reloadRows(at: [IndexPath(row: index + 1, section: 2)], with: .automatic)
        updateButton()
    }

    func didUpdateSettingsValue(index: Int, content: Any?) {
        let option = optionsRows[index + 1]
        settingsValue[option] = content
        updateButton()
    }

    func didTapOnActionButton(index: Int) {
        // Not needed
    }
}

// MARK: - TableView Methods

extension NewFolderViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .header, .location:
            return 1
        case .permissions:
            return permissionsRows.count
        case .options:
            return optionsRows.count
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 100
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let sectionHeaderView = NewFolderSectionHeaderView.instantiate()
            if folderType == .commonFolder {
                sectionHeaderView.titleLabel.text = KDriveResourcesStrings.Localizable.createCommonFolderDescription
            } else {
                sectionHeaderView.titleLabel.text = KDriveResourcesStrings.Localizable.createFolderAccessPermissionTitle
            }
            return sectionHeaderView
        } else if section == 2 && folderType == .commonFolder {
            let sectionHeaderView = NewFolderSectionHeaderView.instantiate()
            sectionHeaderView.titleLabel.text = KDriveResourcesStrings.Localizable.allPathTitle
            return sectionHeaderView
        }
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == sections.count - 1 {
            return 124
        }
        return 18
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 {
            let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonCreateFolder)
            view.delegate = self
            view.footerButton.isEnabled = enableButton
            return view
        }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .header:
            let cell = tableView.dequeueReusableCell(type: NewFolderHeaderTableViewCell.self, for: indexPath)
            cell.delegate = self
            cell.configureWith(folderType: folderType)
            return cell
        case .permissions:
            let cell = tableView.dequeueReusableCell(type: NewFolderShareRuleTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true, radius: 6)
            switch permissionsRows[indexPath.row] {
            case .meOnly:
                cell.configureMeOnly()
            case .allUsers:
                cell.configureAllUsers(driveName: driveFileManager.drive.name)
            case .someUser:
                cell.configureSomeUser()
            case .parentsRights:
                cell.configureParentsRights(folderName: currentDirectory.name, fileAccess: fileAccess)
            }
            return cell
        case .location:
            let cell = tableView.dequeueReusableCell(type: NewFolderLocationTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true, radius: 6)
            cell.configure(with: driveFileManager.drive)
            return cell
        case .options:
            let option = optionsRows[indexPath.row]
            switch option {
            case .header:
                let cell = tableView.dequeueReusableCell(type: NewFolderSettingsTitleTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: !showSettings)
                cell.accessoryImageView.transform = CGAffineTransform.identity
                if showSettings {
                    cell.accessoryImageView.transform = cell.accessoryImageView.transform.rotated(by: .pi / 2)
                }
                return cell
            default:
                let cell = tableView.dequeueReusableCell(type: NewFolderSettingsTableViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: false, isLast: indexPath.row == optionsRows.count - 1)
                cell.delegate = self
                cell.configureFor(
                    index: indexPath.row - 1,
                    switchValue: getSetting(for: option),
                    settingValue: getValue(for: option)
                )
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch sections[indexPath.section] {
        case .header, .location:
            return nil
        case .permissions:
            return indexPath
        case .options:
            if optionsRows[indexPath.row] == .header {
                showSettings.toggle()
                optionsRows = showSettings ? OptionsRow.allCases : [.header]
                UIView.animate(withDuration: 0.2) {
                    let cell = tableView.cellForRow(at: indexPath) as! NewFolderSettingsTitleTableViewCell
                    if self.showSettings {
                        cell.accessoryImageView.transform = cell.accessoryImageView.transform.rotated(by: .pi / 2)
                    } else {
                        cell.accessoryImageView.transform = cell.accessoryImageView.transform.rotated(by: .pi / -2)
                    }
                    cell.layoutIfNeeded()
                }
                tableView.reloadSections([indexPath.section], with: .automatic)
            }
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        updateButton()
    }
}

// MARK: - FooterButtonDelegate

extension NewFolderViewController: FooterButtonDelegate {
    func didClickOnButton(_ sender: IKLargeButton) {
        let footer = tableView.footerView(forSection: sections.count - 1) as! FooterButtonView
        footer.footerButton.setLoading(true)
        footer.footerButton.layoutIfNeeded()
        switch folderType {
        case .folder:
            let onlyForMe: Bool
            let toShare: Bool
            if let indexPath = tableView.indexPathForSelectedRow {
                onlyForMe = sections[indexPath.section] == .permissions && permissionsRows[indexPath.row] == .meOnly
                toShare = sections[indexPath.section] == .permissions && permissionsRows[indexPath.row] == .someUser
            } else {
                onlyForMe = false
                toShare = false
            }
            Task { [proxyCurrentDirectory = currentDirectory.proxify()] in
                do {
                    let frozenDirectory = try await driveFileManager.createDirectory(
                        in: proxyCurrentDirectory,
                        name: newFolderName,
                        onlyForMe: onlyForMe
                    )
                    if toShare {
                        guard let liveDirectory = liveDirectory(forUid: frozenDirectory.uid) else {
                            UIConstants.showSnackBarIfNeeded(error: DriveError.fileNotFound)
                            return
                        }
                        let shareVC = ShareAndRightsViewController.instantiate(
                            driveFileManager: self.driveFileManager,
                            liveFile: liveDirectory
                        )
                        self.folderCreated = true
                        self.navigationController?.pushViewController(shareVC, animated: true)
                    } else {
                        self.dismissAndRefreshDataSource()
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.createPrivateFolderSucces)
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
                footer.footerButton.setLoading(false)
            }
        case .commonFolder:
            let forAllUser = tableView.indexPathForSelectedRow?.row == 0
            Task {
                do {
                    let frozenDirectory = try await driveFileManager.createCommonDirectory(
                        name: newFolderName,
                        forAllUser: forAllUser
                    )
                    if !forAllUser {
                        guard let liveDirectory = liveDirectory(forUid: frozenDirectory.uid) else {
                            UIConstants.showSnackBarIfNeeded(error: DriveError.fileNotFound)
                            return
                        }
                        let shareVC = ShareAndRightsViewController.instantiate(
                            driveFileManager: self.driveFileManager,
                            liveFile: liveDirectory
                        )
                        self.folderCreated = true
                        self.navigationController?.pushViewController(shareVC, animated: true)
                    } else {
                        self.dismissAndRefreshDataSource()
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.createCommonFolderSucces)
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
                footer.footerButton.setLoading(false)
            }
        case .dropbox:
            let onlyForMe = tableView.indexPathForSelectedRow?.row == 0
            let password: String? = getSetting(for: .optionPassword) ? (getValue(for: .optionPassword) as? String) : nil
            let validUntil: Date? = getSetting(for: .optionDate) ? (getValue(for: .optionDate) as? Date) : nil
            let limitFileSize: BinaryDisplaySize?
            if getSetting(for: .optionSize), let size = getValue(for: .optionSize) as? Double {
                limitFileSize = .gibibytes(size)
            } else {
                limitFileSize = nil
            }
            let settings = DropBoxSettings(
                alias: nil,
                emailWhenFinished: getSetting(for: .optionMail),
                limitFileSize: limitFileSize,
                password: password,
                validUntil: validUntil
            )
            matomo.trackDropBoxSettings(settings, passwordEnabled: getSetting(for: .optionPassword))
            Task { [proxyCurrentDirectory = currentDirectory.proxify()] in
                do {
                    let frozenDirectory = try await driveFileManager.createDropBox(
                        parentDirectory: proxyCurrentDirectory,
                        name: newFolderName,
                        onlyForMe: onlyForMe,
                        settings: settings
                    )
                    if !onlyForMe {
                        guard let liveDirectory = liveDirectory(forUid: frozenDirectory.uid) else {
                            UIConstants.showSnackBarIfNeeded(error: DriveError.fileNotFound)
                            return
                        }
                        let shareVC = ShareAndRightsViewController.instantiate(
                            driveFileManager: self.driveFileManager,
                            liveFile: liveDirectory
                        )
                        self.folderCreated = true
                        self.dropBoxUrl = frozenDirectory.dropbox?.url ?? ""
                        self.folderName = frozenDirectory.name
                        self.navigationController?.pushViewController(shareVC, animated: true)
                    } else {
                        self.showDropBoxLink(url: frozenDirectory.dropbox?.url ?? "", fileName: frozenDirectory.name)
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
                footer.footerButton.setLoading(false)
            }
        }
    }

    private func liveDirectory(forUid directoryUid: String) -> File? {
        return driveFileManager.database.fetchObject(
            ofType: File.self,
            forPrimaryKey: directoryUid
        )
    }
}
