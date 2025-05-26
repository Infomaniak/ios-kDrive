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

class IKSelectButton: IKLargeButton {
    override var isSelected: Bool {
        didSet {
            setBackgroundColor()
        }
    }

    override func setUpButton() {
        style.disabledBackgroundColor = KDriveResourcesAsset.borderColor.color

        super.setUpButton()

        setTitle("", for: .selected)
        setTitle("", for: [.selected, .disabled])
        setImage(KDriveResourcesAsset.bigCheck.image, for: .selected)
        setImage(KDriveResourcesAsset.bigCheck.image, for: [.selected, .disabled])
        setTitleColor(style.backgroundColor, for: .normal)
        setTitleColor(style.titleColor, for: .selected)
        setTitleColor(style.titleColor, for: [.selected, .disabled])
    }

    override func setBackgroundColor() {
        if isSelected {
            super.setBackgroundColor()
            borderWidth = 0
        } else {
            backgroundColor = nil
            borderColor = isEnabled ? style.backgroundColor : style.disabledBackgroundColor
            borderWidth = 1
        }
    }
}
