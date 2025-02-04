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

protocol NewFolderSettingsDelegate: AnyObject {
    func didUpdateSettings(index: Int, isOn: Bool)
    func didUpdateSettingsValue(index: Int, content: Any?)
    func didTapOnActionButton(index: Int)
}

class NewFolderSettingsTableViewCell: InsetTableViewCell {
    @IBOutlet var bottomStackView: UIStackView!
    @IBOutlet var settingSwitch: UISwitch!
    @IBOutlet var detailLabel: UILabel!
    @IBOutlet var actionButton: UIButton!
    @IBOutlet var textField: MaterialOutlinedTextField!
    @IBOutlet var textFieldStackView: UIStackView!
    @IBOutlet var datePicker: UIDatePicker!
    @IBOutlet var dateTextField: MaterialOutlinedTextField!

    var showPassword = false
    var datePickerView = UIDatePicker()

    weak var delegate: NewFolderSettingsDelegate?
    var cellType: CellType!

    enum CellType: Int {
        case mail, password, date, size
    }

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

        datePickerView.datePickerMode = .date
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.sizeToFit()

        let doneButton = UIBarButtonItem(
            title: KDriveResourcesStrings.Localizable.buttonClose,
            style: .done,
            target: self,
            action: #selector(donePicker)
        )
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
        delegate?.didUpdateSettingsValue(index: cellType.rawValue, content: datePickerView.date)
    }

    @IBAction func settingSwitchChanged(_ sender: UISwitch) {
        delegate?.didUpdateSettings(index: cellType.rawValue, isOn: settingSwitch.isOn)
    }

    @IBAction func textFieldUpdated(_ sender: MaterialOutlinedTextField) {
        textField.borderColor = KDriveResourcesAsset.infomaniakColor.color
        let content: Any?
        switch cellType {
        case .size:
            content = NumberFormatter().number(from: textField.text ?? "")?.doubleValue
        default:
            content = textField.text?.isEmpty == false ? textField.text : nil
        }
        delegate?.didUpdateSettingsValue(index: cellType.rawValue, content: content)
    }

    @IBAction func actionButtonTapped(_ sender: UIButton) {
        delegate?.didTapOnActionButton(index: cellType.rawValue)
    }

    @IBAction func datePickerUpdated(_ sender: UIDatePicker) {
        delegate?.didUpdateSettingsValue(index: cellType.rawValue, content: datePicker.date)
    }

    func configureFor(index: Int, switchValue: Bool, actionButtonVisible: Bool = false, settingValue: Any?) {
        guard let cellType = CellType(rawValue: index) else { return }
        self.cellType = cellType
        settingSwitch.isOn = switchValue

        switch cellType {
        case .mail:
            configureMail()
        case .password:
            configurePassword(switchValue: switchValue, newPassword: actionButtonVisible, setting: settingValue)
        case .date:
            configureDate(switchValue: switchValue, setting: settingValue)
        case .size:
            configureSize(switchValue: switchValue, setting: settingValue)
        }
    }

    func configureMail() {
        titleLabel.text = KDriveResourcesStrings.Localizable.createFolderEmailWhenFinishedTitle
        bottomStackView.isHidden = true
    }

    func configurePassword(switchValue: Bool, newPassword: Bool, setting: Any?) {
        titleLabel.text = KDriveResourcesStrings.Localizable.createFolderPasswordTitle
        detailLabel.text = KDriveResourcesStrings.Localizable.createFolderPasswordDescription
        togglePasswordTextField(newPassword: newPassword)
        textField.setHint(KDriveResourcesStrings.Localizable.allPasswordHint)
        textField.isSecureTextEntry = !showPassword
        textField.keyboardType = .default
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.text = setting as? String

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

        textField.rightView = rightView
        textField.rightViewMode = .always
    }

    @objc func displayPassword() {
        showPassword.toggle()
        textField.isSecureTextEntry = !showPassword
    }

    func togglePasswordTextField(newPassword: Bool) {
        actionButton.isHidden = !newPassword || !settingSwitch.isOn
        textFieldStackView.isHidden = newPassword || !settingSwitch.isOn
        textField.isHidden = newPassword || !settingSwitch.isOn
    }

    func configureDate(switchValue: Bool, setting: Any?) {
        titleLabel.text = KDriveResourcesStrings.Localizable.allAddExpirationDateTitle
        detailLabel.text = KDriveResourcesStrings.Localizable.createFolderValidUntilDescription

        datePicker.isHidden = !switchValue
        datePicker.date = setting as? Date ?? Date()

        if switchValue {
            datePickerUpdated(datePicker)
        }
    }

    func configureSize(switchValue: Bool, setting: Any?) {
        titleLabel.text = KDriveResourcesStrings.Localizable.createFolderLimitFileSizeTitle
        detailLabel.text = KDriveResourcesStrings.Localizable.createFolderLimitFileSizeDescription
        textField.isHidden = !switchValue
        textFieldStackView.isHidden = !switchValue
        textField.isSecureTextEntry = false
        textField.keyboardType = .decimalPad
        textField.setHint(nil)
        if switchValue {
            let value = setting as? Double ?? 0
            textField.text = NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
            textFieldUpdated(textField)
        }

        let label = UILabel()
        label.text = KDriveResourcesStrings.Localizable.createFolderLimitFileSizeUnitTitle
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
        textField.borderColor = KDriveResourcesAsset.infomaniakColor.color
        if cellType == .size && textField.text == "0" {
            textField.selectAll(nil)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
}
