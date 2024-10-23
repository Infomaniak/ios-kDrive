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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import MaterialOutlinedTextField
import UIKit

protocol ShareLinkSettingsDelegate: AnyObject {
    func didUpdateSettings(index: Int, isOn: Bool)
    func didUpdateSettingsValue(index: Int, content: Any?)
    func didTapOnActionButton(index: Int)
}

class ShareLinkSettingTableViewCell: InsetTableViewCell {
    @IBOutlet var settingSwitch: UISwitch!
    @IBOutlet var settingDetail: UILabel!
    @IBOutlet var passwordTextField: MaterialOutlinedTextField!
    @IBOutlet var newPasswordButton: IKButton!
    @IBOutlet var compactDatePicker: UIDatePicker!
    @IBOutlet var updateButton: UIButton!

    var option: ShareLinkSettingsViewController.OptionsRow?
    weak var delegate: ShareLinkSettingsDelegate?

    var actionHandler: ((UIButton) -> Void)?

    var showPassword = false
    var index: Int!

    override func awakeFromNib() {
        super.awakeFromNib()
        passwordTextField.isHidden = true
        compactDatePicker.isHidden = true
        updateButton.isHidden = true
        newPasswordButton.isHidden = true

        compactDatePicker.minimumDate = Date()

        passwordTextField.delegate = self
        passwordTextField.setInfomaniakColors()
        passwordTextField.isAccessibilityElement = true

        passwordTextField.setHint(KDriveResourcesStrings.Localizable.allPasswordHint)
        passwordTextField.isSecureTextEntry = !showPassword
        passwordTextField.keyboardType = .default
        passwordTextField.autocorrectionType = .no
        passwordTextField.autocapitalizationType = .none

        let overlayButton = UIButton(type: .custom)
        let viewImage = KDriveResourcesAsset.view.image
        overlayButton.setImage(viewImage, for: .normal)
        overlayButton.tintColor = KDriveResourcesAsset.iconColor.color
        overlayButton.addTarget(self, action: #selector(displayPassword), for: .touchUpInside)
        overlayButton.sizeToFit()
        overlayButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonTogglePassword
        let rightView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: overlayButton.frame.width + 10,
            height: overlayButton.frame.height
        ))
        rightView.addSubview(overlayButton)
        passwordTextField.rightView = rightView
        passwordTextField.rightViewMode = .always
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        contentInsetView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        contentInsetView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
    }

    @IBAction func compactDatePickerChanged(_ sender: UIDatePicker) {
        delegate?.didUpdateSettingsValue(index: index, content: compactDatePicker.date)
    }

    func configureWith(
        index: Int,
        option: ShareLinkSettingsViewController.OptionsRow,
        switchValue: Bool,
        settingValue: Any?,
        drive: Drive,
        actionButtonVisible: Bool = false,
        isFolder: Bool
    ) {
        self.option = option
        self.index = index

        titleLabel.text = option.title
        settingDetail.text = isFolder ? option.folderDescription : option.fileDescription
        settingSwitch.isOn = switchValue
        settingSwitch.isEnabled = option.isEnabled(drive: drive)
        updateButton.isHidden = option.isEnabled(drive: drive)
        passwordTextField.isHidden = true
        newPasswordButton.isHidden = true
        compactDatePicker.isHidden = true

        if option == .optionDate {
            compactDatePicker.isHidden = !switchValue
            if let date = settingValue as? Date {
                compactDatePicker.date = date
            } else {
                compactDatePicker.date = Date()
            }

            if switchValue {
                compactDatePickerChanged(compactDatePicker)
            }
        }
        if option == .optionPassword {
            togglePasswordTextField(newPassword: actionButtonVisible)
        }
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        delegate?.didUpdateSettings(index: index, isOn: settingSwitch.isOn)
    }

    @IBAction func updateButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }

    @IBAction func textFieldUpdated(_ sender: MaterialOutlinedTextField) {
        passwordTextField.borderColor = KDriveResourcesAsset.infomaniakColor.color
        let content = passwordTextField.text?.count ?? 0 > 0 ? passwordTextField.text : nil
        delegate?.didUpdateSettingsValue(index: index, content: index == 3 ? Int(passwordTextField.text ?? "0") : content)
    }

    @IBAction func newPasswordButtonPressed(_ sender: IKButton) {
        delegate?.didTapOnActionButton(index: index)
    }

    @objc func displayPassword() {
        showPassword.toggle()
        passwordTextField.isSecureTextEntry = !showPassword
    }

    func togglePasswordTextField(newPassword: Bool) {
        newPasswordButton.isHidden = !newPassword || !settingSwitch.isOn
        passwordTextField.isHidden = newPassword || !settingSwitch.isOn
    }
}

extension ShareLinkSettingTableViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        passwordTextField.borderColor = KDriveResourcesAsset.infomaniakColor.color
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        passwordTextField.endEditing(true)
        return true
    }
}
