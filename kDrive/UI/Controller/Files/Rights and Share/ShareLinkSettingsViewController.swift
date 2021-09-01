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

import kDriveCore
import UIKit

class ShareLinkSettingsViewController: UIViewController {
    @IBOutlet weak var tableview: UITableView!
    var driveFileManager: DriveFileManager!

    enum Option: CaseIterable {
        case expirationDate, allowDownload, blockUsersConsult, blockComments

        var title: String {
            switch self {
            case .expirationDate:
                return KDriveStrings.Localizable.allAddExpirationDateTitle
            case .allowDownload:
                return KDriveStrings.Localizable.shareLinkSettingsAllowDownloadTitle
            case .blockUsersConsult:
                return KDriveStrings.Localizable.shareLinkSettingsBlockUsersConsultTitle
            case .blockComments:
                return KDriveStrings.Localizable.shareLinkSettingsBlockCommentsTitle
            }
        }

        var description: String {
            switch self {
            case .expirationDate:
                return KDriveStrings.Localizable.shareLinkSettingsAddExpirationDateDescription
            case .allowDownload:
                return KDriveStrings.Localizable.shareLinkSettingsAllowDownloadDescription
            case .blockUsersConsult:
                return KDriveStrings.Localizable.shareLinkSettingsBlockUsersConsultDescription
            case .blockComments:
                return KDriveStrings.Localizable.shareLinkSettingsBlockCommentsDescription
            }
        }

        func isEnabled(drive: Drive) -> Bool {
            if self == .expirationDate && drive.pack == .free {
                return false
            } else {
                return true
            }
        }
    }

    let accessRights = Right.shareLinkRights
    var file: File!
    var shareFile: SharedFile!
    private var optionsValue = [Option: Bool]()
    var accessRightValue: String!
    var expirationDate: TimeInterval?
    var content: [Option] = [.expirationDate, .allowDownload]
    var password: String?
    var enableButton = true {
        didSet {
            guard let footer = tableview.footerView(forSection: tableview.numberOfSections - 1) as? FooterButtonView else {
                return
            }
            footer.footerButton.isEnabled = enableButton
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = KDriveStrings.Localizable.fileShareLinkSettingsTitle

        tableview.delegate = self
        tableview.dataSource = self
        tableview.register(cellView: ShareLinkAccessRightTableViewCell.self)
        tableview.register(cellView: ShareLinkSettingTableViewCell.self)
        tableview.separatorColor = .clear

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        hideKeyboardWhenTappedAround()
        initOptions()
        updateButton()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableview.contentInset.bottom = keyboardSize.height

            UIView.animate(withDuration: 0.1) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        tableview.contentInset.bottom = 0
        UIView.animate(withDuration: 0.1) {
            self.view.layoutIfNeeded()
        }
    }

    func updateButton() {
        if (optionsValue[.expirationDate] ?? false) && expirationDate == nil {
            enableButton = false
        } else {
            if accessRightValue == "password" && password?.count ?? 0 < 1 {
                enableButton = false
            } else {
                enableButton = true
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if #available(iOS 13.0, *) {
            let navigationBarAppearanceStandard = UINavigationBarAppearance()
            navigationBarAppearanceStandard.configureWithTransparentBackground()
            navigationBarAppearanceStandard.backgroundColor = KDriveAsset.backgroundCardViewColor.color
            navigationItem.standardAppearance = navigationBarAppearanceStandard

            let navigationBarAppearanceLarge = UINavigationBarAppearance()
            navigationBarAppearanceLarge.configureWithTransparentBackground()
            navigationBarAppearanceLarge.backgroundColor = KDriveAsset.backgroundCardViewColor.color
            navigationItem.scrollEdgeAppearance = navigationBarAppearanceLarge
        } else {
            navigationController?.navigationBar.isTranslucent = false
            navigationController?.navigationBar.barTintColor = KDriveAsset.backgroundCardViewColor.color
            navigationController?.navigationBar.shadowImage = UIImage()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableview.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    private func initOptions() {
        guard shareFile != nil else { return }
        // Access right
        accessRightValue = shareFile.link!.permission
        // Options
        optionsValue = [
            .expirationDate: shareFile.link!.validUntil != nil,
            .allowDownload: !shareFile.link!.blockDownloads,
            .blockUsersConsult: shareFile.link!.blockInformation,
            .blockComments: shareFile.link!.blockComments
        ]
        expirationDate = shareFile.link!.validUntil != nil ? TimeInterval(shareFile.link!.validUntil!) : nil
    }

    private func getValue(for option: Option) -> Bool {
        return optionsValue[option] ?? false
    }

    class func instantiate() -> ShareLinkSettingsViewController {
        return Storyboard.files.instantiateViewController(withIdentifier: "ShareLinkSettingsViewController") as! ShareLinkSettingsViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(file.id, forKey: "FileId")
        coder.encode(shareFile, forKey: "ShareFile")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let fileId = coder.decodeInteger(forKey: "FileId")
        shareFile = coder.decodeObject(forKey: "ShareFile") as? SharedFile
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        file = driveFileManager.getCachedFile(id: fileId)
        // Update UI
        initOptions()
        updateButton()
        tableview.reloadData()
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension ShareLinkSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count + 1
        // return Option.allCases.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Access right
        if indexPath.row == 0 {
            let cell = tableview.dequeueReusableCell(type: ShareLinkAccessRightTableViewCell.self, for: indexPath)
            cell.accessRightLabel.text = nil
            cell.accessRightImage.image = nil
            cell.delegate = self
            if let right = accessRights.first(where: { $0.key == accessRightValue }) {
                cell.accessRightView.accessibilityLabel = right.title
                cell.accessRightLabel.text = right.title
                cell.accessRightImage.image = right.icon
                if accessRightValue == "password" {
                    if shareFile.link?.permission == "password" {
                        cell.buttonNewPassword.isHidden = false
                    } else {
                        cell.textField.isHidden = false
                    }
                }
            }
            return cell
        }
        // Options
        let cell = tableview.dequeueReusableCell(type: ShareLinkSettingTableViewCell.self, for: indexPath)
        cell.delegate = self
        let option = content[indexPath.row - 1]
        cell.configureWith(option: option, optionValue: getValue(for: option), drive: driveFileManager.drive, expirationTime: expirationDate)
        if !option.isEnabled(drive: driveFileManager.drive) {
            cell.actionHandler = { [self] _ in
                let floatingPanelViewController = SecureLinkFloatingPanelViewController.instantiatePanel()
                (floatingPanelViewController.contentViewController as? SecureLinkFloatingPanelViewController)?.actionHandler = { [weak self] _ in
                    guard let self = self else { return }
                    UIConstants.openUrl("\(ApiRoutes.orderDrive())/\(driveFileManager.drive.id)", from: self)
                }
                self.present(floatingPanelViewController, animated: true)
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == tableView.numberOfSections - 1 {
            return 124
        }
        return 28
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableView.numberOfSections - 1 {
            let view = FooterButtonView.instantiate(title: KDriveStrings.Localizable.buttonSave)
            view.delegate = self
            view.footerButton.isEnabled = enableButton
            view.background.backgroundColor = tableview.backgroundColor
            return view
        }
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let rightsSelectionViewController = RightsSelectionViewController.instantiateInNavigationController()
            rightsSelectionViewController.modalPresentationStyle = .fullScreen
            if let rightsSelectionVC = rightsSelectionViewController.viewControllers.first as? RightsSelectionViewController {
                rightsSelectionVC.driveFileManager = driveFileManager
                rightsSelectionVC.selectedRight = accessRightValue
                rightsSelectionVC.rightSelectionType = .shareLinkSettings
                rightsSelectionVC.delegate = self
            }
            present(rightsSelectionViewController, animated: true)
        }
    }
}

// MARK: - ShareLinkSettingsDelegate

extension ShareLinkSettingsViewController: ShareLinkSettingsDelegate {
    func didUpdateExpirationDateSettingValue(for option: Option, newValue value: Bool, date: TimeInterval?) {
        optionsValue[option] = value
        expirationDate = date
        updateButton()
        if let index = Option.allCases.firstIndex(of: option) {
            tableview.reloadRows(at: [IndexPath(row: index + 1, section: 0)], with: .automatic)
        }
    }

    func didUpdateSettingValue(for option: Option, newValue value: Bool) {
        optionsValue[option] = value
    }
}

// MARK: - RightsSelectionDelegate

extension ShareLinkSettingsViewController: RightsSelectionDelegate {
    func didUpdateRightValue(newValue value: String) {
        accessRightValue = value
        updateButton()
    }
}

// MARK: - AccessRightPasswordDelegate

extension ShareLinkSettingsViewController: AccessRightPasswordDelegate {
    func didUpdatePassword(newPassword: String) {
        password = newPassword
        updateButton()
    }
}

// MARK: - FooterButtonDelegate

extension ShareLinkSettingsViewController: FooterButtonDelegate {
    func didClickOnButton() {
        driveFileManager.apiFetcher.updateShareLinkWith(file: file, canEdit: shareFile.link!.canEdit, permission: accessRightValue, password: password, date: expirationDate, blockDownloads: !getValue(for: .allowDownload), blockComments: getValue(for: .blockComments), blockInformation: getValue(for: .blockUsersConsult), isFree: driveFileManager.drive.pack == .free) { response, _ in
            if response?.data == true {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}
