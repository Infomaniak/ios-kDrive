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
import kDriveResources
import UIKit

class LocationTableViewCell: InsetTableViewCell {
    @IBOutlet var logoImage: UIImageView!

    func configure(with drive: Drive?) {
        logoImage.image = KDriveResourcesAsset.drive.image

        if let drive {
            titleLabel.text = drive.name
            logoImage.tintColor = UIColor(hex: drive.preferences.color)
        } else {
            titleLabel.text = KDriveResourcesStrings.Localizable.selectDriveTitle
            logoImage.tintColor = KDriveResourcesAsset.secondaryTextColor.color
        }
    }

    func configure(with folder: File?, drive: Drive) {
        if let folder {
            if folder.isRoot {
                configure(with: drive)
                titleLabel.text = KDriveResourcesStrings.Localizable.allRootName(drive.name)
            } else {
                titleLabel.text = folder.formattedLocalizedName(drive: drive)
                logoImage.image = folder.icon
                logoImage.tintColor = folder.tintColor
            }
        } else {
            titleLabel.text = KDriveResourcesStrings.Localizable.selectFolderTitle
            logoImage.image = KDriveResourcesAsset.folderFilled.image
        }
    }

    func configure(with filterType: FilterType, filters: Filters) {
        switch filterType {
        case .date:
            titleLabel.text = filters.date?.localizedName ?? KDriveResourcesStrings.Localizable.searchFiltersSelectDate
            logoImage.image = KDriveResourcesAsset.calendar.image
            logoImage.tintColor = KDriveResourcesAsset.iconColor.color
        case .type:
            titleLabel.text = filters.fileType?.title ?? KDriveResourcesStrings.Localizable.searchFiltersSelectType
            logoImage.image = filters.fileType?.icon ?? KDriveResourcesAsset.fileDefault.image
            switch filters.fileType {
            case .text:
                logoImage.tintColor = KDriveResourcesAsset.infomaniakColor.color
            default:
                logoImage.tintColor = KDriveResourcesAsset.iconColor.color
            }
        case .categories:
            titleLabel.text = ""
            logoImage.image = KDriveResourcesAsset.categories.image
            logoImage.tintColor = KDriveResourcesAsset.iconColor.color
        }
    }
}
