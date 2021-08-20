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

class ManageDropBoxViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!

    var driveFileManager: DriveFileManager!
    var folder: File! {
        didSet {
            setTitle()
            getSettings()
        }
    }

    var convertingFolder = false {
        didSet { setTitle() }
    }

    private enum Section: CaseIterable {
        case shareLink, options, disable
    }

    private enum OptionsRow: CaseIterable {
        case optionMail, optionPassword, optionDate, optionSize
    }

    private var sections: [Section] {
        return convertingFolder ? [.options] : Section.allCases
    }

    private let optionsRows = OptionsRow.allCases

    private var dropBox: DropBox?
    private var settings = [OptionsRow: Bool]()
    private var settingsValue = [OptionsRow: Any?]()
    private var newPassword = false

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.layoutMargins.left = 24
        navigationController?.navigationBar.layoutMargins.right = 24

        tableView.register(cellView: DropBoxDisableTableViewCell.self)
        tableView.register(cellView: DropBoxLinkTableViewCell.self)
        tableView.register(cellView: NewFolderSettingsTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 16

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    class func instantiate() -> ManageDropBoxViewController {
        return Storyboard.files.instantiateViewController(withIdentifier: "ManageDropBoxViewController") as! ManageDropBoxViewController
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

    private func setTitle() {
        guard folder != nil else { return }
        let truncatedName: String
        if folder.name.count > 20 {
            truncatedName = folder.name[folder.name.startIndex ..< folder.name.index(folder.name.startIndex, offsetBy: 20)] + "…"
        } else {
            truncatedName = folder.name
        }
        navigationItem.title = convertingFolder ? KDriveStrings.Localizable.convertToDropboxTitle(truncatedName) : KDriveStrings.Localizable.manageDropboxTitle(folder.name)
    }

    private func getSettings() {
        if convertingFolder {
            settings = [
                .optionMail: true,
                .optionPassword: false,
                .optionDate: false,
                .optionSize: false
            ]
            settingsValue = [
                .optionPassword: nil,
                .optionDate: nil,
                .optionSize: nil
            ]
            newPassword = false
        } else {
            driveFileManager.apiFetcher.getDropBoxSettings(directory: folder) { response, _ in
                self.dropBox = response?.data
                if let dropBox = response?.data {
                    self.settings = [
                        .optionMail: dropBox.emailWhenFinished,
                        .optionPassword: dropBox.password,
                        .optionDate: dropBox.validUntil != nil,
                        .optionSize: dropBox.limitFileSize != nil
                    ]
                    self.settingsValue = [
                        .optionPassword: nil,
                        .optionDate: dropBox.validUntil,
                        .optionSize: dropBox.limitFileSize
                    ]
                    self.newPassword = dropBox.password
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                }
                self.tableView.reloadData()
            }
        }
    }

    private func getSetting(for option: OptionsRow) -> Bool {
        return settings[option] ?? false
    }

    private func getValue(for option: OptionsRow) -> Any? {
        return settingsValue[option] ?? nil
    }

    func dismissAndRefreshDataSource() {
        let mainTabViewController = UIApplication.shared.keyWindow?.rootViewController as? UITabBarController
        let fileNavigationController = mainTabViewController?.selectedViewController as? UINavigationController
        if let viewControllers = fileNavigationController?.viewControllers, viewControllers.count > 1 {
            let fileListViewController = viewControllers[viewControllers.count - 2] as? FileListViewController
            fileListViewController?.getNewChanges()
        }
        navigationController?.popViewController(animated: true)
    }

    func updateButton(footer: FooterButtonView? = nil) {
        var activateButton = true
        for (option, enabled) in settings {
            // Disable the button if the option is enabled but has no value, except in case of mail and password
            if option != .optionMail && enabled && getValue(for: option) == nil && (option != .optionPassword || !newPassword) {
                activateButton = false
            }
        }
        let footer = tableView.footerView(forSection: tableView.numberOfSections - 1) as? FooterButtonView ?? footer
        footer?.footerButton.isEnabled = activateButton
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .shareLink, .disable:
            return 1
        case .options:
            return optionsRows.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .shareLink:
            let cell = tableView.dequeueReusableCell(type: DropBoxLinkTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            cell.delegate = self
            cell.copyTextField.text = dropBox?.url
            return cell
        case .options:
            let option = optionsRows[indexPath.row]
            let cell = tableView.dequeueReusableCell(type: NewFolderSettingsTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == optionsRows.count - 1)
            cell.delegate = self
            cell.configureFor(index: indexPath.row, switchValue: getSetting(for: option), actionButtonVisible: option == .optionPassword && newPassword, settingValue: getValue(for: option))
            return cell
        case .disable:
            let cell = tableView.dequeueReusableCell(type: DropBoxDisableTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: true, isLast: true)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 {
            return 124
        }
        return 16
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 {
            let view = FooterButtonView.instantiate(title: KDriveStrings.Localizable.buttonSave)
            view.delegate = self
            updateButton(footer: view)
            return view
        }
        return nil
    }

    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 {
            driveFileManager.apiFetcher.disableDropBox(directory: folder) { _, error in
                if error == nil {
                    self.dismissAndRefreshDataSource()
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorModification)
                }
            }
        }
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(folder.id, forKey: "FolderId")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let folderId = coder.decodeInteger(forKey: "FolderId")
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        folder = driveFileManager.getCachedFile(id: folderId)
    }
}

// MARK: - NewFolderSettingsDelegate

extension ManageDropBoxViewController: NewFolderSettingsDelegate {
    func didUpdateSettings(index: Int, isOn: Bool) {
        let option = optionsRows[index]
        settings[option] = isOn
        tableView.reloadRows(at: [IndexPath(row: index, section: convertingFolder ? 0 : 1)], with: .automatic)
        updateButton()
    }

    func didUpdateSettingsValue(index: Int, content: Any?) {
        let option = optionsRows[index]
        settingsValue[option] = content
        updateButton()
    }

    func didTapOnActionButton(index: Int) {
        let option = optionsRows[index]
        if option == .optionPassword {
            newPassword.toggle()
        }
        tableView.reloadRows(at: [IndexPath(row: index, section: convertingFolder ? 0 : 1)], with: .automatic)
        updateButton()
    }
}

// MARK: - FooterButtonDelegate

extension ManageDropBoxViewController: FooterButtonDelegate {
    func didClickOnButton() {
        let password = getSetting(for: .optionPassword) ? (getValue(for: .optionPassword) as? String) : ""
        let validUntil = getSetting(for: .optionDate) ? (getValue(for: .optionDate) as? Date) : nil
        let limitFileSize = getSetting(for: .optionSize) ? (getValue(for: .optionSize) as? Int) : nil

        if convertingFolder {
            driveFileManager.apiFetcher.setupDropBox(directory: folder, password: (password?.isEmpty ?? false) ? nil : password, validUntil: validUntil, emailWhenFinished: getSetting(for: .optionMail), limitFileSize: limitFileSize) { response, _ in
                if let dropBox = response?.data {
                    let floatingPanelViewController = ShareFloatingPanelViewController.instantiatePanel()
                    (floatingPanelViewController.contentViewController as? ShareFloatingPanelViewController)?.copyTextField.text = dropBox.url
                    (floatingPanelViewController.contentViewController as? ShareFloatingPanelViewController)?.titleLabel.text = KDriveStrings.Localizable.dropBoxResultTitle(self.folder.name)
                    self.present(floatingPanelViewController, animated: true)
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                }
            }
        } else {
            driveFileManager.apiFetcher.updateDropBox(directory: folder, password: password, validUntil: validUntil, emailWhenFinished: getSetting(for: .optionMail), limitFileSize: limitFileSize) { _, error in
                if error == nil {
                    self.navigationController?.popViewController(animated: true)
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorModification)
                }
            }
        }
    }
}

extension ManageDropBoxViewController: DropBoxLinkDelegate {
    func didClickOnShareLink(link: String, sender: UIView) {
        let items = [URL(string: link)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = sender
        present(ac, animated: true)
    }
}
