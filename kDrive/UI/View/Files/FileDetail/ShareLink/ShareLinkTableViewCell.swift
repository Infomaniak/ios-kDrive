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
    func shareLinkSettingsButtonPressed()
    func shareLinkSharedButtonPressed(link: String, sender: UIView)
}

class ShareLinkTableViewCell: InsetTableViewCell {
    @IBOutlet weak var shareLinkTitleLabel: IKLabel!
    @IBOutlet weak var shareIconImageView: UIImageView!
    @IBOutlet weak var rightArrow: UIImageView!
    @IBOutlet weak var shareLinkStackView: UIStackView!
    @IBOutlet weak var shareLinkDescriptionLabel: UILabel!
    @IBOutlet weak var copyButton: ImageButton!
    @IBOutlet weak var topInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomInnerConstraint: NSLayoutConstraint!

    weak var delegate: ShareLinkTableViewCellDelegate?
    var url = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        copyButton.accessibilityLabel = KDriveStrings.Localizable.buttonShare
        selectionStyle = .default
    }

    func configureWith(sharedFile: SharedFile?, file: File, insets: Bool = true) {
        if insets {
            topInnerConstraint.constant = 16
            bottomInnerConstraint.constant = 16
            leadingConstraint.constant = 24
            trailingConstraint.constant = 24
        } else {
            topInnerConstraint.constant = 8
            bottomInnerConstraint.constant = 8
            initWithoutInsets()
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
            rightArrow.isHidden = true
            shareIconImageView.image = KDriveAsset.folderDropBox.image
        } else {
            shareLinkTitleLabel.text = KDriveStrings.Localizable.restrictedSharedLinkTitle
            shareLinkDescriptionLabel.text = file.isDirectory ? KDriveStrings.Localizable.shareLinkRestrictedRightFolderDescription : KDriveStrings.Localizable.shareLinkRestrictedRightFileDescription
            shareLinkStackView.isHidden = true
        }
    }

    func initWithoutInsets() {
        initWithPositionAndShadow()
        leadingConstraint.constant = 0
        trailingConstraint.constant = 0
    }
    
    @IBAction func copyButtonPressed(_ sender: UIButton) {
        delegate?.shareLinkSharedButtonPressed(link: url, sender: sender)
    }

    @IBAction func shareLinkSettingsButtonPressed(_ sender: Any) {
        delegate?.shareLinkSettingsButtonPressed()
    }
}
