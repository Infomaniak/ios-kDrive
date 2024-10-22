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

class AlertTableViewCell: UITableViewCell {
    @IBOutlet var view: UIView!
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var messageLabel: IKLabel!

    enum Style {
        case info, warning
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        view.cornerRadius = UIConstants.cornerRadius
    }

    func configure(with style: Style, message: String) {
        switch style {
        case .info:
            iconImageView.image = KDriveResourcesAsset.infoFilled.image
            iconImageView.tintColor = KDriveResourcesAsset.infomaniakColor.color
        case .warning:
            iconImageView.image = KDriveResourcesAsset.warning.image
            iconImageView.tintColor = KDriveResourcesAsset.warningColor.color
        }
        messageLabel.text = message
    }
}
