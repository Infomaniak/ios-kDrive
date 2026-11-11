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

import kDriveResources
import UIKit

class InfoTableViewCell: UITableViewCell {
    @IBOutlet private var infoImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var actionButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        infoImageView.image = KDriveResourcesAsset.info.image
        infoImageView.tintColor = KDriveResourcesAsset.infomaniakColor.color
        titleLabel.textColor = KDriveResourcesAsset.titleColor.color
        actionButton.backgroundColor = KDriveResourcesAsset.infomaniakColor.color
    }

    var actionHandler: ((UIButton) -> Void)?

    @IBAction func buttonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
