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

class HomeLastPicCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var contentInsetView: UIView!
    @IBOutlet weak var fileImage: UIImageView!
    @IBOutlet weak var darkLayer: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        fileImage.layer.masksToBounds = true
        darkLayer.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        darkLayer.isHidden = true
        fileImage.image = nil
        fileImage.backgroundColor = nil
    }

    override var isHighlighted: Bool {
        didSet {
            darkLayer.isHidden = !isHighlighted
        }
    }

    func configureLoading() {
        darkLayer.isHidden = true
        fileImage.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color
        contentInsetView.cornerRadius = UIConstants.cornerRadius
    }

    func configureWith(file: File, roundedCorners: Bool = true) {
        darkLayer.isHidden = false
        file.getThumbnail { image, isThumbnail in
            self.darkLayer.isHidden = true
            self.fileImage.image = isThumbnail ? image : KDriveAsset.fileImageSmall.image
        }
        accessibilityLabel = file.name
        isAccessibilityElement = true
        if roundedCorners {
            contentInsetView.cornerRadius = UIConstants.cornerRadius
        }
    }
}
