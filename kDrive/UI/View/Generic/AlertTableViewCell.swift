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
import UIKit

class AlertTableViewCell: UITableViewCell {
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var messageLabel: IKLabel!

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
            iconImageView.image = KDriveAsset.info.image
            iconImageView.tintColor = KDriveAsset.infomaniakColor.color
        case .warning:
            iconImageView.image = KDriveAsset.warning.image
            iconImageView.tintColor = KDriveAsset.warningColor.color
        }
        messageLabel.text = message
    }
}
