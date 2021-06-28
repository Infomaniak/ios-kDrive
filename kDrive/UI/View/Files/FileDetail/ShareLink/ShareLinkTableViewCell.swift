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

protocol ShareLinkTableViewCellDelegate: AnyObject {
    func shareLinkSwitchToggled(isOn: Bool)
    func shareLinkRightsButtonPressed()
    func shareLinkSettingsButtonPressed()
}

class ShareLinkTableViewCell: InsetTableViewCell {

    @IBOutlet weak var shareLinkSwitch: UISwitch!
    @IBOutlet weak var shareLinkStackView: UIStackView!
    @IBOutlet weak var activeLabel: UILabel!
    @IBOutlet weak var copyTextField: UITextField!
    @IBOutlet weak var copyButton: ImageButton!
    @IBOutlet weak var shareLinkRightsView: UIView!
    @IBOutlet weak var rightsIconImageView: UIImageView!
    @IBOutlet weak var rightsLabel: UILabel!
    @IBOutlet weak var topInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomInnerConstraint: NSLayoutConstraint!

    var insets = true
    weak var delegate: ShareLinkTableViewCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        shareLinkRightsView.layer.borderWidth = 1
        shareLinkRightsView.layer.borderColor = KDriveAsset.borderColor.color.cgColor
        shareLinkRightsView.layer.cornerRadius = UIConstants.buttonCornerRadius
        shareLinkRightsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(shareLinkRightsButtonPressed)))
        shareLinkRightsView.accessibilityTraits = .button
        shareLinkRightsView.isAccessibilityElement = true
        copyButton.accessibilityLabel = KDriveStrings.Localizable.buttonCopy
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if !insets {
            contentInsetView.backgroundColor = .clear
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if !insets {
            contentInsetView.backgroundColor = .clear
        }
    }

    func configureWith(sharedFile: SharedFile?, isOfficeFile: Bool, enabled: Bool, insets: Bool = true) {
        self.insets = insets
        if insets {
            topInnerConstraint.constant = 16
            leadingInnerConstraint.constant = 16
            trailingInnerConstraint.constant = 16
            bottomInnerConstraint.constant = 16
        } else {
            topInnerConstraint.constant = 8
            leadingInnerConstraint.constant = 0
            trailingInnerConstraint.constant = 0
            bottomInnerConstraint.constant = 8
        }
        layoutIfNeeded()
        if let link = sharedFile?.link {
            shareLinkSwitch.isOn = true
            activeLabel.text = KDriveStrings.Localizable.allActivated
            shareLinkStackView.isHidden = false
            copyTextField.text = link.url
            shareLinkRightsView.isHidden = !isOfficeFile
            let right = Right.onlyOfficeRights[link.canEdit ? 1 : 0]
            rightsIconImageView.image = right.icon
            rightsLabel.text = right.title
            shareLinkRightsView.accessibilityLabel = right.title
        } else {
            shareLinkSwitch.isOn = false
            activeLabel.text = KDriveStrings.Localizable.allDisabled
            shareLinkStackView.isHidden = true
        }
        shareLinkSwitch.isEnabled = enabled
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        UIPasteboard.general.url = URL(string: copyTextField.text ?? "")
        UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileInfoLinkCopiedToClipboard)
    }

    @IBAction func shareLinkSwitchChanged(_ sender: UISwitch) {
        delegate?.shareLinkSwitchToggled(isOn: sender.isOn)
    }

    @objc func shareLinkRightsButtonPressed() {
        delegate?.shareLinkRightsButtonPressed()
    }

    @IBAction func shareLinkSettingsButtonPressed(_ sender: Any) {
        delegate?.shareLinkSettingsButtonPressed()
    }
}
