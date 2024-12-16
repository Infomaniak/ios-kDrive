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

import InfomaniakCoreUIKit
import kDriveCore
import UIKit

class CategoryCollectionViewCell: UICollectionViewCell {
    @IBOutlet var chipView: UIView!
    @IBOutlet var categoryLabel: IKLabel!

    func configure(with category: kDriveCore.Category) {
        chipView.backgroundColor = category.color
        categoryLabel.text = category.localizedName
        chipView.cornerRadius = min(chipView.bounds.height, chipView.bounds.width) / 2
    }
}
