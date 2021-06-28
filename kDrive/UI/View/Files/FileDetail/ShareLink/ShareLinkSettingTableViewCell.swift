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

protocol ShareLinkSettingsDelegate: AnyObject {
    func didUpdateSettingValue(for option: ShareLinkSettingsViewController.Option, newValue value: Bool)
    func didUpdateExpirationDateSettingValue(for option: ShareLinkSettingsViewController.Option, newValue value: Bool, date: TimeInterval?)
}

class ShareLinkSettingTableViewCell: InsetTableViewCell {

    @IBOutlet weak var settingSwitch: UISwitch!
    @IBOutlet weak var settingDetail: UILabel!
    @IBOutlet weak var dateTextField: UITextField!
    @IBOutlet weak var compactDatePicker: UIDatePicker!
    @IBOutlet weak var updateButton: UIButton!

    var option: ShareLinkSettingsViewController.Option?
    weak var delegate: ShareLinkSettingsDelegate?
    var datePickerView = UIDatePicker()
    var expirationDate: Date?

    var actionHandler: ((UIButton) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        dateTextField.isHidden = true
        compactDatePicker.isHidden = true
        updateButton.isHidden = true

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
        dateTextField.text = Constants.formatDate(datePickerView.date, style: .date)
        expirationDate = datePickerView.date
        delegate?.didUpdateExpirationDateSettingValue(for: .expirationDate, newValue: settingSwitch.isOn, date: expirationDate?.timeIntervalSince1970)
    }

    @IBAction func compactDatePickerChanged(_ sender: UIDatePicker) {
        dateTextField.text = "\(sender.date)"
        expirationDate = sender.date
        delegate?.didUpdateExpirationDateSettingValue(for: .expirationDate, newValue: settingSwitch.isOn, date: expirationDate?.timeIntervalSince1970)
    }

    func configureWith(option: ShareLinkSettingsViewController.Option, optionValue: Bool, drive: Drive, expirationTime: TimeInterval? = nil) {
        self.option = option

        titleLabel.text = option.title
        settingDetail.text = option.description
        settingSwitch.isOn = optionValue
        settingSwitch.isEnabled = option.isEnabled(drive: drive)
        updateButton.isHidden = option.isEnabled(drive: drive)

        if option == .expirationDate {
            self.expirationDate = expirationTime != nil ? Date(timeIntervalSince1970: expirationTime!) : nil
            if #available(iOS 13.4, *) {
                compactDatePicker.isHidden = !optionValue
                if let date = expirationDate {
                    compactDatePicker.date = date
                }
            } else {
                dateTextField.isHidden = !optionValue
                if let date = expirationDate {
                    dateTextField.text = Constants.formatDate(date, style: .date)
                }
            }
        }
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        guard let option = option else {
            return
        }

        if option == .expirationDate {
            let date = sender.isOn ? expirationDate : nil
            delegate?.didUpdateExpirationDateSettingValue(for: option, newValue: sender.isOn, date: date?.timeIntervalSince1970)
        } else {
            delegate?.didUpdateSettingValue(for: option, newValue: sender.isOn)
        }
    }

    @IBAction func updateButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
