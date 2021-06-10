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

class FileDetailInformationUserCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var moreLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImage.image = KDriveAsset.placeholderAvatar.image
        avatarImage.cornerRadius = avatarImage.bounds.width / 2
        moreLabel.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.image = KDriveAsset.placeholderAvatar.image
    }

    func configureWith(moreValue: Int, driveUser: DriveUser) {
        if moreValue > 0 {
            moreLabel.isHidden = false
            moreLabel.text = "+\(moreValue)"
            accessibilityLabel = "\(driveUser.displayName) +\(moreValue)"
        } else {
            accessibilityLabel = driveUser.displayName
        }
        isAccessibilityElement = true

        driveUser.getAvatar { image in
            self.avatarImage.image = image
        }
    }
}
