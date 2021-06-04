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
import MaterialOutlinedTextField

protocol AccessRightPasswordDelegate: AnyObject {
    func didUpdatePassword(newPassword: String)
}

class ShareLinkAccessRightTableViewCell: InsetTableViewCell {

    @IBOutlet weak var accessRightView: UIView!
    @IBOutlet weak var accessRightLabel: UILabel!
    @IBOutlet weak var accessRightImage: UIImageView!
    @IBOutlet weak var textField: MaterialOutlinedTextField!
    @IBOutlet weak var buttonNewPassword: UIButton!

    var showPassword = false
    weak var delegate: AccessRightPasswordDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        accessRightView.isAccessibilityElement = true
        accessRightView.accessibilityTraits = .button

        titleLabel.text = KDriveStrings.Localizable.fileShareLinkSettingsAccessRightTitle
        buttonNewPassword.setTitle(KDriveStrings.Localizable.buttonNewPassword, for: .normal)

        textField.delegate = self
        textField.setInfomaniakColors()
        textField.isHidden = true
        textField.isAccessibilityElement = true
        buttonNewPassword.isHidden = true

        textField.setHint(KDriveStrings.Localizable.allPasswordHint)
        textField.isSecureTextEntry = !showPassword
        textField.keyboardType = .default
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none

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

    override func prepareForReuse() {
        super.prepareForReuse()
        textField.isHidden = true
        buttonNewPassword.isHidden = true
    }

    @IBAction func textFieldUpdated(_ sender: MaterialOutlinedTextField) {
        textField.borderColor = KDriveAsset.infomaniakColor.color
        delegate?.didUpdatePassword(newPassword: textField.text ?? "")
    }

    @IBAction func buttonNewPasswordClicked(_ sender: UIButton) {
        delegate?.didUpdatePassword(newPassword: textField.text ?? "")
        buttonNewPassword.isHidden = true
        textField.isHidden = false
    }

    @objc func displayPassword() {
        showPassword.toggle()
        textField.isSecureTextEntry = !showPassword
    }
}

extension ShareLinkAccessRightTableViewCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.borderColor = KDriveAsset.infomaniakColor.color
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }

}
