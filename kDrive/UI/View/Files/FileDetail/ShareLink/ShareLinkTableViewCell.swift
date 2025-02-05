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
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

protocol ShareLinkTableViewCellDelegate: AnyObject {
    func shareLinkSettingsButtonPressed()
    func shareLinkSharedButtonPressed(link: String, sender: UIView)
}

class ShareLinkTableViewCell: InsetTableViewCell {
    @LazyInjectService private var router: AppNavigable

    @IBOutlet var shareLinkTitleLabel: IKLabel!
    @IBOutlet var shareIconImageView: UIImageView!
    @IBOutlet var rightArrow: UIImageView!
    @IBOutlet var shareLinkStackView: UIStackView!
    @IBOutlet var shareLinkDescriptionLabel: UILabel!
    @IBOutlet var copyButton: ImageButton!
    @IBOutlet var leadingConstraint: NSLayoutConstraint!
    @IBOutlet var trailingConstraint: NSLayoutConstraint!
    @IBOutlet var leadingInnerConstraint: NSLayoutConstraint!
    @IBOutlet var trailingInnerConstraint: NSLayoutConstraint!
    @IBOutlet var separatorView: UIView!
    @IBOutlet var chipContainerView: UIView!
    @IBOutlet var fileShareLinkSettingTitle: IKButton!

    weak var delegate: ShareLinkTableViewCellDelegate?
    var url = ""
    var selectedPackId: DrivePackId?

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
                    self.contentInsetView.backgroundColor = selected ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                        .color : self.contentBackgroundColor
                }
            } else {
                contentInsetView.backgroundColor = selected ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                    .color : contentBackgroundColor
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
                    self.contentInsetView.backgroundColor = highlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                        .color : self.contentBackgroundColor
                }
            } else {
                contentInsetView.backgroundColor = highlighted ? KDriveResourcesAsset.backgroundCardViewSelectedColor
                    .color : contentBackgroundColor
            }
        } else {
            contentInsetView.backgroundColor = contentBackgroundColor
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        chipContainerView.subviews.forEach { $0.removeFromSuperview() }
    }

    func configureWith(file: File, displayChip: Bool = false, selectedPackId: DrivePackId?, insets: Bool = true) {
        self.selectedPackId = selectedPackId
        selectionStyle = file.isDropbox ? .none : .default
        if insets {
            leadingConstraint.constant = 24
            trailingConstraint.constant = 24
            leadingInnerConstraint.constant = 16
            trailingInnerConstraint.constant = 16
            separatorView.isHidden = true
        } else {
            initWithoutInsets()
        }

        if let shareLink = file.sharelink {
            shareLinkTitleLabel.text = KDriveResourcesStrings.Localizable.publicSharedLinkTitle
            let rightPermission = (shareLink.capabilities.canEdit ? KDriveResourcesStrings.Localizable
                .shareLinkOfficePermissionWriteTitle : KDriveResourcesStrings.Localizable.shareLinkOfficePermissionReadTitle)
                .lowercased()
            let documentType = file.isDirectory ? KDriveResourcesStrings.Localizable.shareLinkTypeFolder : file
                .isOfficeFile ? KDriveResourcesStrings.Localizable.shareLinkTypeDocument : KDriveResourcesStrings.Localizable
                .shareLinkTypeFile
            let password = shareLink.right == ShareLinkPermission.password.rawValue ? KDriveResourcesStrings.Localizable
                .shareLinkPublicRightDescriptionPassword : ""
            let date = shareLink.validUntil != nil ? KDriveResourcesStrings.Localizable
                .shareLinkPublicRightDescriptionDate(Constants.formatDate(shareLink.validUntil!)) : ""
            shareLinkDescriptionLabel.text = KDriveResourcesStrings.Localizable.shareLinkPublicRightDescription(
                rightPermission,
                documentType,
                password,
                date
            )
            shareLinkStackView.isHidden = false
            fileShareLinkSettingTitle.alpha = 1
            fileShareLinkSettingTitle.isUserInteractionEnabled = true
            url = shareLink.url
            shareIconImageView.image = KDriveResourcesAsset.unlock.image
        } else if file.isDropbox {
            shareLinkTitleLabel.text = KDriveResourcesStrings.Localizable.dropboxSharedLinkTitle
            shareLinkDescriptionLabel.text = KDriveResourcesStrings.Localizable.dropboxSharedLinkDescription
            shareLinkStackView.isHidden = true
            url = ""
            rightArrow.isHidden = true
            shareIconImageView.image = KDriveResourcesAsset.folderDropBox.image
        } else {
            shareLinkTitleLabel.text = KDriveResourcesStrings.Localizable.restrictedSharedLinkTitle
            shareLinkDescriptionLabel.text = file.isDirectory ? KDriveResourcesStrings.Localizable
                .shareLinkRestrictedRightFolderDescriptionShort : file.isOfficeFile ? KDriveResourcesStrings.Localizable
                .shareLinkRestrictedRightDocumentDescriptionShort : KDriveResourcesStrings.Localizable
                .shareLinkRestrictedRightFileDescriptionShort
            shareLinkStackView.isHidden = false
            url = file.privateSharePath(host: ApiEnvironment.current.driveHost)
            fileShareLinkSettingTitle.alpha = 0
            fileShareLinkSettingTitle.isUserInteractionEnabled = false
            shareIconImageView.image = KDriveResourcesAsset.lock.image
        }

        if displayChip {
            let chipView = MyKSuiteChip.instantiateGreyChip()

            chipView.translatesAutoresizingMaskIntoConstraints = false
            chipContainerView.addSubview(chipView)

            NSLayoutConstraint.activate([
                chipView.leadingAnchor.constraint(greaterThanOrEqualTo: chipContainerView.leadingAnchor),
                chipView.trailingAnchor.constraint(greaterThanOrEqualTo: chipContainerView.trailingAnchor),
                chipView.topAnchor.constraint(equalTo: chipContainerView.topAnchor),
                chipView.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor)
            ])
        }

        layoutIfNeeded()
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
        // TODO: Remove force display
//        if let selectedPackId, selectedPackId == .myKSuite {
            router.presentUpSaleSheet()
            return
//        }
//        MatomoUtils.track(eventWithCategory: .shareAndRights, name: "shareButton")
//        delegate?.shareLinkSharedButtonPressed(link: url, sender: sender)
    }

    @IBAction func shareLinkSettingsButtonPressed(_ sender: Any) {
        // TODO: Remove force display
//        if let selectedPackId, selectedPackId == .myKSuite {
            router.presentUpSaleSheet()
            return
//        }
//        delegate?.shareLinkSettingsButtonPressed()
    }
}
