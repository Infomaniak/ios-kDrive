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

class FloatingPanelTitleTableViewCell: InsetTableViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var availableOfflineImageView: UIImageView!
    @IBOutlet weak var favoriteImageView: UIImageView!

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 0
        iconImageView.layer.masksToBounds = false
    }

    func configureWith(file: File) {
        iconImageView.image = file.icon
        if (file.convertedType == .image || file.convertedType == .video) && file.hasThumbnail {
            iconImageView.image = nil
            iconImageView.contentMode = .scaleAspectFill
            iconImageView.layer.cornerRadius = UIConstants.imageCornerRadius
            iconImageView.layer.masksToBounds = true
            iconImageView.backgroundColor = KDriveAsset.loaderDefaultColor.color
            file.getThumbnail { image, _ in
                self.iconImageView.image = image
                self.iconImageView.backgroundColor = nil
            }
        }
        favoriteImageView.isHidden = !file.isFavorite
        availableOfflineImageView.isHidden = !file.isAvailableOffline
        separator?.isHidden = true
        titleLabel.text = file.name
        let formattedDate = Constants.formatFileLastModifiedDate(file.lastModifiedDate)
        detailLabel.text = file.isDirectory ? formattedDate : file.getFileSize() + " • " + formattedDate
    }

}
