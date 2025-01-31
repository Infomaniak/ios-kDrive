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

class UploadFolderTableViewCell: InsetTableViewCell {
    @IBOutlet var progressView: RPCircularProgress!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var folderLabel: IKLabel!
    @IBOutlet var subtitleLabel: IKLabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        progressView.setInfomaniakStyle()
    }

    func configure(with folder: File, drive: Drive) {
        if folder.isRoot {
            iconImageView.image = KDriveResourcesAsset.drive.image
            iconImageView.tintColor = UIColor(hex: drive.preferences.color)
            folderLabel.text = KDriveResourcesStrings.Localizable.allRootName(drive.name)
            subtitleLabel.isHidden = true
        } else {
            iconImageView.image = KDriveResourcesAsset.folderFilled.image
            iconImageView.tintColor = nil
            folderLabel.text = folder.formattedLocalizedName(drive: drive)
            subtitleLabel.text = folder.path
            subtitleLabel.isHidden = folder.path?.isEmpty != false
        }
        progressView.enableIndeterminate()
    }
}
