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
import DropDown

class UsersDropDownTableViewCell: DropDownCell {

    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImage.layer.cornerRadius = avatarImage.frame.height / 2
        avatarImage.clipsToBounds = true
        avatarImage.image = KDriveAsset.placeholderAvatar.image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.image = KDriveAsset.placeholderAvatar.image
    }

    func configureWith(mail: String) {
        usernameLabel.text = mail
        detailLabel.text = KDriveStrings.Localizable.userInviteByEmail
        avatarImage.image = KDriveAsset.circleSend.image
    }

    func configureWith(user: DriveUser) {
        usernameLabel.text = user.displayName
        detailLabel.text = user.email

        user.getAvatar { (image) in
            self.avatarImage.image = image
                .resizeImage(size: CGSize(width: 35, height: 35))
                .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                .withRenderingMode(.alwaysOriginal)
        }
    }

    func configureWith(account: Account) {
        usernameLabel.text = account.user.displayName
        detailLabel.text = account.user.email
        account.user.getAvatar { (image) in
            self.avatarImage.image = image
        }
    }
}
