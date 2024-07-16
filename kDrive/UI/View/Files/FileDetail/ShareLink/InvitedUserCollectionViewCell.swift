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

import kDriveResources
import UIKit

class InvitedUserCollectionViewCell: UICollectionViewCell {
    @IBOutlet var contentInsetView: UIView!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var avatarImage: UIImageView!
    @IBOutlet var removeButton: UIButton!
    @IBOutlet var widthConstraint: NSLayoutConstraint!

    var removeButtonHandler: ((UIButton) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image
        removeButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonDelete
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentInsetView.roundCorners(
            corners: [.layerMaxXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMinXMinYCorner],
            radius: 10
        )
        removeButton.tintColor = KDriveResourcesAsset.primaryTextColor.color
        avatarImage.layer.cornerRadius = avatarImage.frame.height / 2
        avatarImage.clipsToBounds = true
    }

    @IBAction func closeButton(_ sender: UIButton) {
        removeButtonHandler?(sender)
    }
}
