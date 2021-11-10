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

protocol ShareLinkTableViewCellDelegate: AnyObject {
    func shareLinkRightsButtonPressed()
    func shareLinkSettingsButtonPressed()
    func shareLinkSharedButtonPressed(link: String, sender: UIView)
}

class ShareLinkTableViewCell: InsetTableViewCell {
    @IBOutlet weak var shareLinkSwitch: UISwitch!
    @IBOutlet weak var shareLinkTitleLabel: IKLabel!
    @IBOutlet weak var shareIconImageView: UIImageView!
    @IBOutlet weak var shareLinkStackView: UIStackView!
    @IBOutlet weak var shareLinkDescriptionLabel: UILabel!
    @IBOutlet weak var copyButton: ImageButton!
    @IBOutlet weak var topInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomInnerConstraint: NSLayoutConstraint!

    var insets = true
    weak var delegate: ShareLinkTableViewCellDelegate?
    var url = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        copyButton.accessibilityLabel = KDriveStrings.Localizable.buttonShare
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

    func configureWith(sharedFile: SharedFile?, file: File, enabled: Bool, insets: Bool = true) {
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
            shareLinkTitleLabel.text = KDriveStrings.Localizable.publicSharedLinkTitle
            shareLinkDescriptionLabel.text = file.isDirectory ? KDriveStrings.Localizable.shareLinkPublicRightFolderDescription : KDriveStrings.Localizable.shareLinkPublicRightFileDescription
            shareLinkStackView.isHidden = false
            url = link.url
        } else if file.visibility == .isCollaborativeFolder {
            shareLinkTitleLabel.text = KDriveStrings.Localizable.dropboxSharedLinkTitle
            shareLinkDescriptionLabel.text = KDriveStrings.Localizable.dropboxSharedLinkDescription
            shareLinkStackView.isHidden = true
        } else {
            shareLinkTitleLabel.text = KDriveStrings.Localizable.restrictedSharedLinkTitle
            shareLinkDescriptionLabel.text = file.isDirectory ? KDriveStrings.Localizable.shareLinkRestrictedRightFolderDescription : KDriveStrings.Localizable.shareLinkRestrictedRightFileDescription
            shareLinkStackView.isHidden = true
        }
        shareLinkSwitch.isEnabled = enabled
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        delegate?.shareLinkSharedButtonPressed(link: url, sender: sender)
    }

    @objc func shareLinkRightsButtonPressed() {
        delegate?.shareLinkRightsButtonPressed()
    }

    @IBAction func shareLinkSettingsButtonPressed(_ sender: Any) {
        delegate?.shareLinkSettingsButtonPressed()
    }
}
