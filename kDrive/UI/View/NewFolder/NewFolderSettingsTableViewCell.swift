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
import InfomaniakCore
import kDriveCore
import MaterialOutlinedTextField

protocol NewFolderSettingsDelegate: AnyObject {
    func didUpdateSettings(index: Int, isOn: Bool)
    func didUpdateSettingsValue(index: Int, content: Any?)
    func didTapOnActionButton(index: Int)
}

class NewFolderSettingsTableViewCell: InsetTableViewCell {

    @IBOutlet weak var bottomStackView: UIStackView!
    @IBOutlet weak var settingSwitch: UISwitch!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var textField: MaterialOutlinedTextField!
    @IBOutlet weak var textFieldStackView: UIStackView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var dateTextField: MaterialOutlinedTextField!

    var showPassword: Bool = false
    var datePickerView: UIDatePicker = UIDatePicker()

    weak var delegate: NewFolderSettingsDelegate?
    var index: Int!

    override func awakeFromNib() {
        super.awakeFromNib()
        textField.delegate = self

        textField.setInfomaniakColors()
        dateTextField.setInfomaniakColors()

        datePicker.minimumDate = Date()

        bottomStackView.isHidden = false
        settingSwitch.isOn = false
        actionButton.isHidden = true
        textFieldStackView.isHidden = true
        datePicker.isHidden = true
        dateTextField.isHidden = true

        textField.rightView = nil

        datePickerView.datePickerMode = UIDatePicker.Mode.date
        let toolBar = UIToolbar()
        toolBar.barStyle = UIBarStyle.default
        toolBar.isTranslucent = true
        toolBar.sizeToFit()

        let doneButton = UIBarButtonItem(title: KDriveStrings.Localizable.buttonClose, style: .done, target: self, action: #selector(donePicker))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        toolBar.setItems([spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true

        dateTextField.inputView = datePickerView
        dateTextField.inputAccessoryView = toolBar
        datePickerView.addTarget(self, action: #selector(handleDatePicker), for: UIControl.Event.valueChanged)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        textField.sizeToFit()
        textField.placeholder = nil
        bottomStackView.isHidden = false
        settingSwitch.isOn = false
        actionButton.isHidden = true
        textFieldStackView.isHidden = true
        datePicker.isHidden = true
        textField.rightView = nil
    }

    @objc func donePicker() {
        handleDatePicker()
        dateTextField.endEditing(true)
    }

    @objc func handleDatePicker() {
        dateTextField.text = Constants.formatDate(datePickerView.date, style: .date)
        delegate?.didUpdateSettingsValue(index: index, content: datePickerView.date)
    }

    @IBAction func settingSwitchChanged(_ sender: UISwitch) {
        delegate?.didUpdateSettings(index: index, isOn: settingSwitch.isOn)
    }

    @IBAction func textFieldUpdated(_ sender: MaterialOutlinedTextField) {
        textField.borderColor = KDriveAsset.infomaniakColor.color
        let content = textField.text?.count ?? 0 > 0 ? textField.text : nil
        delegate?.didUpdateSettingsValue(index: index, content: index == 3 ? Int(textField.text ?? "0") : content)
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        delegate?.didTapOnActionButton(index: index)
    }

    @IBAction func datePickerUpdated(_ sender: UIDatePicker) {
        delegate?.didUpdateSettingsValue(index: index, content: datePicker.date)
    }

    func configureFor(index: Int, switchValue: Bool, actionButtonVisible: Bool = false, settingValue: Any?) {
        self.index = index
        settingSwitch.isOn = switchValue

        switch index {
        case 0:
            configureMail()
        case 1:
            configurePassword(switchValue: switchValue, newPassword: actionButtonVisible, setting: settingValue)
        case 2:
            configureDate(switchValue: switchValue, setting: settingValue)
        default:
            configureSize(switchValue: switchValue, setting: settingValue)
        }
    }

    func configureMail() {
        titleLabel.text = KDriveStrings.Localizable.createFolderEmailWhenFinishedTitle
        bottomStackView.isHidden = true
    }

    func configurePassword(switchValue: Bool, newPassword: Bool, setting: Any?) {
        titleLabel.text = KDriveStrings.Localizable.createFolderPasswordTitle
        detailLabel.text = KDriveStrings.Localizable.createFolderPasswordDescription
        togglePasswordTextField(newPassword: newPassword)
        textField.setHint(KDriveStrings.Localizable.allPasswordHint)
        textField.isSecureTextEntry = !showPassword
        textField.keyboardType = .default
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.text = setting as? String

        let overlayButton = UIButton(type: .custom)
        let viewImage = KDriveAsset.view.image
        overlayButton.setImage(viewImage, for: .normal)
        overlayButton.tintColor = KDriveAsset.iconColor.color
        overlayButton.addTarget(self, action: #selector(displayPassword), for: .touchUpInside)
        overlayButton.sizeToFit()
        overlayButton.accessibilityLabel = KDriveStrings.Localizable.buttonTogglePassword
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: overlayButton.frame.width + 10, height: overlayButton.frame.height))
        rightView.addSubview(overlayButton)

        textField.rightView = rightView
        textField.rightViewMode = .always
    }

    @objc func displayPassword() {
        showPassword = !showPassword
        textField.isSecureTextEntry = !showPassword
    }

    func togglePasswordTextField(newPassword: Bool) {
        actionButton.isHidden = !newPassword || !settingSwitch.isOn
        textFieldStackView.isHidden = newPassword || !settingSwitch.isOn
        textField.isHidden = newPassword || !settingSwitch.isOn
    }

    func configureDate(switchValue: Bool, setting: Any?) {
        titleLabel.text = KDriveStrings.Localizable.allAddExpirationDateTitle
        detailLabel.text = KDriveStrings.Localizable.createFolderValidUntilDescription

        if #available(iOS 13.4, *) {
            datePicker.isHidden = !switchValue
            datePicker.date = setting as? Date ?? Date()
        } else {
            dateTextField.isHidden = !switchValue
            dateTextField.text = Constants.formatDate(setting as? Date ?? Date(), style: .date)
        }

        if switchValue {
            datePickerUpdated(datePicker)
        }
    }

    func configureSize(switchValue: Bool, setting: Any?) {
        titleLabel.text = KDriveStrings.Localizable.createFolderLimitFileSizeTitle
        detailLabel.text = KDriveStrings.Localizable.createFolderLimitFileSizeDescription
        textField.isHidden = !switchValue
        textFieldStackView.isHidden = !switchValue
        textField.isSecureTextEntry = false
        textField.keyboardType = .numberPad
        textField.setHint(nil)
        if switchValue {
            let value = setting as? Int ?? 0
            textField.text = String(value)
            textFieldUpdated(textField)
        }

        let label = UILabel()
        label.text = KDriveStrings.Localizable.createFolderLimitFileSizeUnitTitle
        label.font = UIFont.systemFont(ofSize: 14)
        label.sizeToFit()
        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: label.frame.width + 10, height: label.frame.height))
        rightView.addSubview(label)
        textField.rightView = rightView
        textField.rightViewMode = .always
    }
}

extension NewFolderSettingsTableViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.borderColor = KDriveAsset.infomaniakColor.color
        if index == 3 && textField.text == "0" {
            textField.selectAll(nil)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
}
