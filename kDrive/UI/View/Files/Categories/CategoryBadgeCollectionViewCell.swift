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

import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import UIKit

class CategoryBadgeCollectionViewCell: UICollectionViewCell {
    @IBOutlet var moreLabel: IKLabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        borderColor = KDriveResourcesAsset.backgroundCardViewColor.color
        borderWidth = 1
        cornerRadius = 8
        moreLabel.font = moreLabel.font.withSize(9)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        borderColor = KDriveResourcesAsset.backgroundCardViewColor.color
    }

    func configure(with category: kDriveCore.Category, more: Int? = nil) {
        backgroundColor = category.color
        isAccessibilityElement = true
        if let more {
            moreLabel.text = "+\(more)"
            moreLabel.isHidden = false
            accessibilityLabel = "\(category.localizedName) + \(more)"
        } else {
            moreLabel.isHidden = true
            accessibilityLabel = category.localizedName
        }
    }
}
