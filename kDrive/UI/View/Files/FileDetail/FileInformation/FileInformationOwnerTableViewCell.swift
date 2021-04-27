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

class FileInformationOwnerTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var ownerImage: UIImageView!
    @IBOutlet weak var ownerLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        ownerImage.image = KDriveAsset.placeholderAvatar.image
        ownerImage.cornerRadius = ownerImage.frame.width / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        ownerImage.image = KDriveAsset.placeholderAvatar.image
    }

    func configureWith(file: File) {
        ownerLabel.text = ""
        if let user = DriveInfosManager.instance.getUser(id: file.createdBy) {
            ownerLabel.text = user.displayName
            user.getAvatar { (image) in
                self.ownerImage.image = image
            }
        }
    }
}
