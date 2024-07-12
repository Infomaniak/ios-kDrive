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
import UIKit

class DriveSwitchTableViewCell: InsetTableViewCell {
    struct Style {
        let height: CGFloat
        static let home = Style(height: 91)
        static let selectDrive = Style(height: 75)
        static let switchDrive = Style(height: 72)
    }

    @IBOutlet var heightConstraint: NSLayoutConstraint!
    @IBOutlet var driveImageView: UIImageView!
    @IBOutlet var selectDriveImageView: UIImageView!
    var style: Style = .home {
        didSet {
            heightConstraint.constant = style.height
        }
    }

    func configureWith(drive: Drive) {
        titleLabel.text = drive.name
        driveImageView.tintColor = UIColor(hex: drive.preferences.color)
        accessibilityTraits = .button
    }
}
