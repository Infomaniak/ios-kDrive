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
import InfomaniakCore
import MaterialOutlinedTextField

protocol ShareLinkSettingsDelegate: AnyObject {
//    func didUpdateSettingValue(for option: ShareLinkSettingsViewController.OptionsRow, newValue value: Bool)
//    func didUpdateExpirationDateSettingValue(for option: ShareLinkSettingsViewController.OptionsRow, newValue value: Bool, date: TimeInterval?)
//    func didUpdatePasswordSettingValue(for option: ShareLinkSettingsViewController.OptionsRow, newValue value: Bool)
//    func didUpdatePassword(newPasswordString: String)
//    func didTapOnEditPasswordButton()
    
    func didUpdateSettings(index: Int, isOn: Bool)
    func didUpdateSettingsValue(index: Int, content: Any?)
    func didTapOnActionButton(index: Int)
}

class ShareLinkSettingTableViewCell: InsetTableViewCell {

    @IBOutlet weak var settingSwitch: UISwitch!
    @IBOutlet weak var settingDetail: UILabel!
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var passwordTextField: MaterialOutlinedTextField!
    @IBOutlet weak var newPasswordButton: IKButton!
    @IBOutlet weak var compactDatePicker: UIDatePicker!
    @IBOutlet weak var updateButton: UIButton!

    var option: ShareLinkSettingsViewController.OptionsRow?
    weak var delegate: ShareLinkSettingsDelegate?
    var datePickerView = UIDatePicker()
    var expirationDate: Date?

    var actionHandler: ((UIButton) -> Void)?

    var showPassword = false
    var index: Int!


    override func awakeFromNib() {
        super.awakeFromNib()
        dateTextField.isHidden = true
        passwordTextField.isHidden = true
        compactDatePicker.isHidden = true
        updateButton.isHidden = true
        newPasswordButton.isHidden = true

        datePickerView.datePickerMode = UIDatePicker.Mode.date
        let toolBar = UIToolbar()
        toolBar.barStyle = UIBarStyle.default
        toolBar.isTranslucent = true
        toolBar.sizeToFit()

        let doneButton = UIBarButtonItem(title: KDriveStrings.Localizable.buttonClose, style: .done, target: self, action: #selector(donePicker))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        toolBar.setItems([spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true

        passwordTextField.delegate = self
        passwordTextField.setInfomaniakColors()
        passwordTextField.isAccessibilityElement = true

        passwordTextField.setHint(KDriveStrings.Localizable.allPasswordHint)
        passwordTextField.isSecureTextEntry = !showPassword
        passwordTextField.keyboardType = .default
        passwordTextField.autocorrectionType = .no
        passwordTextField.autocapitalizationType = .none

        let overlayButton = UIButton(type: .custom)
        let viewImage = KDriveAsset.view.image
        overlayButton.setImage(viewImage, for: .normal)
        overlayButton.tintColor = KDriveAsset.iconColor.color
        overlayButton.addTarget(self, action: #selector(displayPassword), for: .touchUpInside)
        overlayButton.sizeToFit()
        overlayButton.accessibilityLabel = KDriveStrings.Localizable.buttonTogglePassword
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: overlayButton.frame.width + 10, height: overlayButton.frame.height))
        rightView.addSubview(overlayButton)
        passwordTextField.rightView = rightView
        passwordTextField.rightViewMode = .always

        dateTextField.inputView = datePickerView
        dateTextField.inputAccessoryView = toolBar
        datePickerView.addTarget(self, action: #selector(handleDatePicker), for: UIControl.Event.valueChanged)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        contentInsetView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        contentInsetView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
    }

    @objc func donePicker() {
        handleDatePicker()
        dateTextField.endEditing(true)
    }

    @objc func handleDatePicker() {
//        dateTextField.text = Constants.formatDate(datePickerView.date, style: .date)
//        expirationDate = datePickerView.date
//        delegate?.didUpdateExpirationDateSettingValue(for: .optionDate, newValue: settingSwitch.isOn, date: expirationDate?.timeIntervalSince1970)
        dateTextField.text = Constants.formatDate(datePickerView.date, style: .date)
        delegate?.didUpdateSettingsValue(index: index, content: datePickerView.date)
    }

    @IBAction func compactDatePickerChanged(_ sender: UIDatePicker) {
//        dateTextField.text = "\(sender.date)"
//        expirationDate = sender.date
//        delegate?.didUpdateExpirationDateSettingValue(for: .optionDate, newValue: settingSwitch.isOn, date: expirationDate?.timeIntervalSince1970)
        delegate?.didUpdateSettingsValue(index: index, content: compactDatePicker.date)
    }

    func configureWith(index: Int, option: ShareLinkSettingsViewController.OptionsRow, switchValue: Bool, settingValue: Any?, drive: Drive, expirationTime: TimeInterval? = nil, actionButtonVisible: Bool = false, isFolder: Bool) {
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
            self.expirationDate = settingValue as? Date ?? Date()
            if #available(iOS 13.4, *) {
                compactDatePicker.isHidden = !switchValue
                compactDatePicker.date = settingValue as? Date ?? Date()
            } else {
                dateTextField.isHidden = !switchValue
                dateTextField.text = Constants.formatDate(settingValue as? Date ?? Date(), style: .date)
            }
        }
        if option == .optionPassword {
            togglePasswordTextField(newPassword: actionButtonVisible)
//            if actionButtonVisible {
//                newPasswordButton.isHidden = !switchValue
//            } else {
//                passwordTextField.isHidden = !switchValue
//            }
        }
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        delegate?.didUpdateSettings(index: index, isOn: settingSwitch.isOn)

//        guard let option = option else {
//            return
//        }
//
//        if option == .optionDate {
//            let date = sender.isOn ? expirationDate : nil
//            delegate?.didUpdateExpirationDateSettingValue(for: option, newValue: sender.isOn, date: date?.timeIntervalSince1970)
//        } else if option == .optionPassword {
//            delegate?.didUpdatePasswordSettingValue(for: option, newValue: sender.isOn)
//        } else {
//            delegate?.didUpdateSettingValue(for: option, newValue: sender.isOn)
//        }
    }

    @IBAction func updateButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }

    @IBAction func textFieldUpdated(_ sender: MaterialOutlinedTextField) {
        passwordTextField.borderColor = KDriveAsset.infomaniakColor.color
        let content = passwordTextField.text?.count ?? 0 > 0 ? passwordTextField.text : nil
        delegate?.didUpdateSettingsValue(index: index, content: index == 3 ? Int(passwordTextField.text ?? "0") : content)
//        delegate?.didUpdatePassword(newPasswordString: passwordTextFiled.text ?? "")
    }

    @IBAction func newPasswordButtonPressed(_ sender: IKButton) {
        // LN: To change
//        delegate?.didUpdatePassword(newPasswordString: passwordTextFiled.text ?? "")
//        delegate?.didTapOnEditPasswordButton()
        delegate?.didTapOnActionButton(index: index)
        newPasswordButton.isHidden = true
        passwordTextField.isHidden = false
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
        passwordTextField.borderColor = KDriveAsset.infomaniakColor.color
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        passwordTextField.endEditing(true)
        return true
    }
}
