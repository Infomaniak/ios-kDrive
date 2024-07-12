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
import kDriveResources
import UIKit

class UserAccountTableViewCell: MenuTableViewCell {
    @IBOutlet var userEmailLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        logoImage.image = KDriveResourcesAsset.placeholderAvatar.image
        logoImage.layer.cornerRadius = logoImage.frame.size.width / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        logoImage.image = KDriveResourcesAsset.placeholderAvatar.image
    }
}
