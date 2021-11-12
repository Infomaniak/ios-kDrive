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
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var leadingInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingInnerConstraint: NSLayoutConstraint!
    @IBOutlet weak var separatorView: UIView!

    weak var delegate: ShareLinkTableViewCellDelegate?
    var url = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        copyButton.accessibilityLabel = KDriveStrings.Localizable.buttonShare
        selectionStyle = .default
    }

    func configureWith(sharedFile: SharedFile?, file: File, insets: Bool = true) {
        selectionStyle = file.visibility == .isCollaborativeFolder ? .none : .default
        if insets {
            leadingConstraint.constant = 24
            trailingConstraint.constant = 24
            leadingInnerConstraint.constant = 16
            trailingInnerConstraint.constant = 16
            separatorView.isHidden = true
        } else {
            initWithoutInsets()
        }
        layoutIfNeeded()
        if let link = sharedFile?.link {
            shareLinkTitleLabel.text = KDriveStrings.Localizable.publicSharedLinkTitle
            let rightPermission = link.canEdit ? KDriveStrings.Localizable.shareLinkOfficePermissionWriteTitle.lowercased() : KDriveStrings.Localizable.shareLinkOfficePermissionReadTitle.lowercased()
            let documentType = file.isDirectory ? KDriveStrings.Localizable.shareLinkTypeFolder : file.isOfficeFile ? KDriveStrings.Localizable.shareLinkTypeDocument : KDriveStrings.Localizable.shareLinkTypeFile
            let password = link.permission == ShareLinkPermission.password.rawValue ? KDriveStrings.Localizable.shareLinkPublicRightDescriptionPassword : ""
            let date = link.validUntil != nil ? KDriveStrings.Localizable.shareLinkPublicRightDescriptionDate(Constants.formatDate(Date(timeIntervalSince1970: Double(link.validUntil!)))) : ""
            shareLinkDescriptionLabel.text = KDriveStrings.Localizable.shareLinkPublicRightDescription(rightPermission, documentType, password, date)
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
            shareLinkDescriptionLabel.text = file.isDirectory ? KDriveStrings.Localizable.shareLinkRestrictedRightFolderDescriptionShort : file.isOfficeFile ? KDriveStrings.Localizable.shareLinkRestrictedRightDocumentDescriptionShort : KDriveStrings.Localizable.shareLinkRestrictedRightFileDescriptionShort
            shareLinkStackView.isHidden = true
        }
    }

    func initWithoutInsets() {
        initWithPositionAndShadow()
        leadingConstraint.constant = 0
        trailingConstraint.constant = 0
        leadingInnerConstraint.constant = 24
        trailingInnerConstraint.constant = 24
        separatorView.isHidden = false
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        delegate?.shareLinkSharedButtonPressed(link: url, sender: sender)
    }

    @IBAction func shareLinkSettingsButtonPressed(_ sender: Any) {
        delegate?.shareLinkSettingsButtonPressed()
    }
}
