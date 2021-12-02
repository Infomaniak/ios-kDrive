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

import kDriveCore
import kDriveResources
import UIKit

class RecentActivityBottomTableViewCell: UITableViewCell {
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileImage: UIImageView!

    override func prepareForReuse() {
        super.prepareForReuse()
        fileNameLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    func configureWith(recentActivity: FileActivity, more: Int?) {
        if let count = more {
            fileImage.image = KDriveResourcesAsset.copy.image
            fileNameLabel.text = KDriveResourcesStrings.Localizable.fileActivityOtherFiles(count)
            fileImage.tintColor = KDriveResourcesAsset.secondaryTextColor.color
        } else {
            fileImage.image = recentActivity.file?.icon ?? ConvertedType.unknown.icon
            fileNameLabel.text = recentActivity.file?.name ?? String(recentActivity.path.split(separator: "/").last ?? "")
            fileImage.tintColor = recentActivity.file?.convertedType.tintColor
        }
        fileImage.backgroundColor = nil
    }

    func configureLoading() {
        fileNameLabel.text = " "
        let fileNameLayer = CALayer()
        fileNameLayer.anchorPoint = .zero
        fileNameLayer.frame = CGRect(x: 0, y: 4, width: 150, height: 10)
        fileNameLayer.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color.cgColor
        fileNameLabel.layer.addSublayer(fileNameLayer)
        fileImage.image = nil
        fileImage.backgroundColor = KDriveResourcesAsset.loaderDarkerDefaultColor.color
    }
}
