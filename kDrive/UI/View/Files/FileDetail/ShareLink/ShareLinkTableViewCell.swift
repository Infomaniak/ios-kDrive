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
import kDriveResources
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

    private var contentBackgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color

    override func awakeFromNib() {
        super.awakeFromNib()
        copyButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonShare
        selectionStyle = .default
    }

    override open func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selectionStyle != .none {
            if animated {
                UIView.animate(withDuration: 0.1) {
                    self.contentInsetView.backgroundColor = selected ? KDriveResourcesAsset.backgroundCardViewSelectedColor.color : self.contentBackgroundColor
                }
            } else {
                contentInsetView.backgroundColor = selected ? KDriveResourcesAsset.backgroundCardViewSelectedColor.color : contentBackgroundColor
            }
        } else {
            contentInsetView.backgroundColor = contentBackgroundColor
        }
    }

    override open func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if selectionStyle != .none {
            if animated {
                UIView.animate(withDuration: 0.1) {
                    self.contentInsetView.backgroundColor = highlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor.color : self.contentBackgroundColor
                }
            } else {
                contentInsetView.backgroundColor = highlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor.color : contentBackgroundColor
            }
        } else {
            contentInsetView.backgroundColor = contentBackgroundColor
        }
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
            shareLinkTitleLabel.text = KDriveResourcesStrings.Localizable.publicSharedLinkTitle
            let rightPermission = link.canEdit ? KDriveResourcesStrings.Localizable.shareLinkOfficePermissionWriteTitle.lowercased() : KDriveResourcesStrings.Localizable.shareLinkOfficePermissionReadTitle.lowercased()
            let documentType = file.isDirectory ? KDriveResourcesStrings.Localizable.shareLinkTypeFolder : file.isOfficeFile ? KDriveResourcesStrings.Localizable.shareLinkTypeDocument : KDriveResourcesStrings.Localizable.shareLinkTypeFile
            let password = link.permission == ShareLinkPermission.password.rawValue ? KDriveResourcesStrings.Localizable.shareLinkPublicRightDescriptionPassword : ""
            let date = link.validUntil != nil ? KDriveResourcesStrings.Localizable.shareLinkPublicRightDescriptionDate(Constants.formatDate(Date(timeIntervalSince1970: Double(link.validUntil!)))) : ""
            shareLinkDescriptionLabel.text = KDriveResourcesStrings.Localizable.shareLinkPublicRightDescription(rightPermission, documentType, password, date)
            shareLinkStackView.isHidden = false
            url = link.url
            shareIconImageView.image = KDriveResourcesAsset.unlock.image
        } else if file.visibility == .isCollaborativeFolder {
            shareLinkTitleLabel.text = KDriveResourcesStrings.Localizable.dropboxSharedLinkTitle
            shareLinkDescriptionLabel.text = KDriveResourcesStrings.Localizable.dropboxSharedLinkDescription
            shareLinkStackView.isHidden = true
            rightArrow.isHidden = true
            shareIconImageView.image = KDriveResourcesAsset.folderDropBox.image
        } else {
            shareLinkTitleLabel.text = KDriveResourcesStrings.Localizable.restrictedSharedLinkTitle
            shareLinkDescriptionLabel.text = file.isDirectory ? KDriveResourcesStrings.Localizable.shareLinkRestrictedRightFolderDescriptionShort : file.isOfficeFile ? KDriveResourcesStrings.Localizable.shareLinkRestrictedRightDocumentDescriptionShort : KDriveResourcesStrings.Localizable.shareLinkRestrictedRightFileDescriptionShort
            shareLinkStackView.isHidden = true
            shareIconImageView.image = KDriveResourcesAsset.lock.image
        }
    }

    func initWithoutInsets() {
        initWithPositionAndShadow()
        leadingConstraint.constant = 0
        trailingConstraint.constant = 0
        leadingInnerConstraint.constant = 24
        trailingInnerConstraint.constant = 24
        separatorView.isHidden = false
        contentBackgroundColor = UIColor.systemBackground
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        delegate?.shareLinkSharedButtonPressed(link: url, sender: sender)
        MatomoUtils.track(eventWithCategory: .shareAndRights, name: "shareButton")
    }

    @IBAction func shareLinkSettingsButtonPressed(_ sender: Any) {
        delegate?.shareLinkSettingsButtonPressed()
    }
}
