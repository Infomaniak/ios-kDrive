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

class ManageDropBoxViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!

    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable

    private var driveFileManager: DriveFileManager!
    private var directory: File! {
        didSet {
            setTitle()
            getSettings()
        }
    }

    private var convertingFolder = false {
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
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.List.paddingBottom, right: 0)
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 16

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
        matomo.track(view: ["ManageDropBox"])
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    class func instantiate(driveFileManager: DriveFileManager, convertingFolder: Bool = false,
                           folder: File) -> ManageDropBoxViewController {
        let viewController = Storyboard.files
            .instantiateViewController(withIdentifier: "ManageDropBoxViewController") as! ManageDropBoxViewController
        viewController.convertingFolder = convertingFolder
        viewController.driveFileManager = driveFileManager
        viewController.directory = folder
        return viewController
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
        guard directory != nil else { return }
        let truncatedName: String
        if directory.name.count > 20 {
            truncatedName = directory.name[directory.name.startIndex ..< directory.name.index(
                directory.name.startIndex,
                offsetBy: 20
            )] + "…"
        } else {
            truncatedName = directory.name
        }
        navigationItem.title = convertingFolder ? KDriveResourcesStrings.Localizable
            .convertToDropboxTitle(truncatedName) : KDriveResourcesStrings.Localizable.manageDropboxTitle(directory.name)
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
        } else if let dropBox = directory.dropbox {
            settings = [
                .optionMail: dropBox.capabilities.hasNotification,
                .optionPassword: dropBox.capabilities.hasPassword,
                .optionDate: dropBox.capabilities.hasValidity,
                .optionSize: dropBox.capabilities.hasSizeLimit
            ]
            let sizeLimit: BinaryDisplaySize?
            if let size = dropBox.capabilities.size.limit {
                sizeLimit = .bytes(UInt64(size))
            } else {
                sizeLimit = nil
            }
            settingsValue = [
                .optionPassword: nil,
                .optionDate: dropBox.capabilities.validity.date,
                .optionSize: sizeLimit?.toGibibytes
            ]
            newPassword = dropBox.capabilities.hasPassword
            if isViewLoaded {
                tableView.reloadData()
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
        let mainTabViewController = view?.window?.rootViewController as? UITabBarController
        let fileNavigationController = mainTabViewController?.selectedViewController as? UINavigationController
        if let viewControllers = fileNavigationController?.viewControllers, viewControllers.count > 1 {
            let fileListViewController = viewControllers[viewControllers.count - 2] as? FileListViewController
            Task {
                try await fileListViewController?.viewModel.loadActivities()
            }
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
            cell.copyTextField.text = directory.dropbox?.url
            return cell
        case .options:
            let option = optionsRows[indexPath.row]
            let cell = tableView.dequeueReusableCell(type: NewFolderSettingsTableViewCell.self, for: indexPath)
            cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == optionsRows.count - 1)
            cell.delegate = self
            cell.configureFor(
                index: indexPath.row,
                switchValue: getSetting(for: option),
                actionButtonVisible: option == .optionPassword && newPassword,
                settingValue: getValue(for: option)
            )
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
            let view = FooterButtonView.instantiate(title: KDriveResourcesStrings.Localizable.buttonSave)
            view.delegate = self
            updateButton(footer: view)
            return view
        }
        return nil
    }

    // MARK: - Table view delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.isUserInteractionEnabled = false
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2 {
            Task { [proxyDirectory = directory.proxify()] in
                defer {
                    self.tableView.isUserInteractionEnabled = true
                }
                do {
                    let response = try await driveFileManager.apiFetcher.deleteDropBox(directory: proxyDirectory)
                    if response {
                        self.dismissAndRefreshDataSource()
                        self.driveFileManager.setFileDropBox(file: proxyDirectory, dropBox: nil)
                    } else {
                        self.navigationController?.popViewController(animated: true)
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorModification)
                    }
                } catch {
                    self.navigationController?.popViewController(animated: true)
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        } else {
            self.tableView.isUserInteractionEnabled = true
        }
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
    func didClickOnButton(_ sender: IKLargeButton) {
        tableView.isUserInteractionEnabled = false
        sender.setLoading(true)

        let password = getSetting(for: .optionPassword) ? (getValue(for: .optionPassword) as? String) : ""
        let validUntil = getSetting(for: .optionDate) ? (getValue(for: .optionDate) as? Date) : nil
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

        Task { [proxyDirectory = directory.proxify()] in
            defer {
                self.tableView.isUserInteractionEnabled = true
                sender.setLoading(false)
            }

            if convertingFolder {
                do {
                    let dropBox = try await driveFileManager.apiFetcher.createDropBox(
                        directory: proxyDirectory,
                        settings: settings
                    )
                    let driveFloatingPanelController = ShareFloatingPanelViewController.instantiatePanel()
                    let floatingPanelViewController = driveFloatingPanelController
                        .contentViewController as? ShareFloatingPanelViewController
                    floatingPanelViewController?.copyTextField.text = dropBox.url
                    floatingPanelViewController?.titleLabel.text = KDriveResourcesStrings.Localizable
                        .dropBoxResultTitle(self.directory.name)
                    self.navigationController?.popViewController(animated: true)
                    self.navigationController?.topViewController?.present(driveFloatingPanelController, animated: true)
                    self.driveFileManager.setFileDropBox(file: proxyDirectory, dropBox: dropBox)
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            } else {
                defer { self.navigationController?.popViewController(animated: true) }
                do {
                    if try await driveFileManager.updateDropBox(directory: proxyDirectory, settings: settings) == false {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorModification)
                    }
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                }
            }
        }
    }
}

extension ManageDropBoxViewController: DropBoxLinkDelegate {
    func didClickOnShareLink(link: String, sender: UIView) {
        matomo.track(eventWithCategory: .dropbox, name: "share")
        let items = [URL(string: link)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = sender
        present(ac, animated: true)
    }
}
