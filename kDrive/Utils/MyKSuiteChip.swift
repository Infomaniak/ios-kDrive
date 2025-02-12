/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import kDriveCore
import kDriveResources
import UIKit

public enum MyKSuiteChip {
    public static func instantiateWhiteChip() -> UIView {
        instantiate(backgroundColor: KDriveResourcesAsset.whiteBackgroundChipColor.color)
    }

    public static func instantiateGrayChip() -> UIView {
        instantiate(backgroundColor: KDriveResourcesAsset.grayBackgroundChipColor.color)
    }

    private static func instantiate(backgroundColor: UIColor) -> UIView {
        let chipContainerView = UIView()
        let chipImage = KDriveResourcesAsset.myKSuitePlusLogo.image
        let chipImageView = UIImageView(image: chipImage)

        chipImageView.translatesAutoresizingMaskIntoConstraints = false
        chipContainerView.addSubview(chipImageView)

        NSLayoutConstraint.activate([
            chipImageView.leadingAnchor.constraint(equalTo: chipContainerView.leadingAnchor, constant: 8),
            chipImageView.trailingAnchor.constraint(equalTo: chipContainerView.trailingAnchor, constant: -8),
            chipImageView.topAnchor.constraint(equalTo: chipContainerView.topAnchor, constant: 4),
            chipImageView.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor, constant: -4)
        ])

        chipContainerView.cornerRadius = 12
        chipContainerView.clipsToBounds = true
        chipContainerView.backgroundColor = backgroundColor
        return chipContainerView
    }
}
