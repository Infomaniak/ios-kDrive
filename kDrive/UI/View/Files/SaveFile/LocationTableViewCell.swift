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

class LocationTableViewCell: InsetTableViewCell {

    @IBOutlet weak var logoImage: UIImageView!

    func configure(with drive: Drive?) {
        logoImage.image = KDriveAsset.drive.image

        if let drive = drive {
            titleLabel.text = drive.name
            logoImage.tintColor = UIColor(hex: drive.preferences.color)
        } else {
            titleLabel.text = KDriveStrings.Localizable.selectDriveTitle
            logoImage.tintColor = KDriveAsset.secondaryTextColor.color
        }
    }

    func configure(with folder: File?, drive: Drive) {
        if let folder = folder {
            if folder.isRoot {
                configure(with: drive)
                titleLabel.text = KDriveStrings.Localizable.allRootName(drive.name)
            } else {
                titleLabel.text = folder.name
                folder.getThumbnail { image, _ in
                    self.logoImage.image = image
                }
                logoImage.tintColor = nil
            }
        } else {
            titleLabel.text = KDriveStrings.Localizable.selectFolderTitle
            logoImage.image = KDriveAsset.folderFilled.image
        }
    }

    func configure(with filterType: FilterType, filters: Filters) {
        switch filterType {
        case .date:
            titleLabel.text = "Sélectionner une date"
            logoImage.image = KDriveAsset.calendar.image
        case .type:
            titleLabel.text = "Sélectionner un type de fichier"
            logoImage.image = filters.fileType?.icon ?? KDriveAsset.fileDefault.image
        case .categories:
            titleLabel.text = ""
            logoImage.image = KDriveAsset.categories.image
        }
        logoImage.tintColor = KDriveAsset.secondaryTextColor.color
    }
}
