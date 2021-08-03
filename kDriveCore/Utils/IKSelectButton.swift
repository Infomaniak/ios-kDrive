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

class IKSelectButton: IKLargeButton {
    override var isSelected: Bool {
        didSet {
            setBackgroundColor()
        }
    }

    override func setUpButton() {
        super.setUpButton()

        setTitle("", for: .selected)
        setImage(KDriveCoreAsset.bigCheck.image, for: .selected)
        setTitleColor(style.backgroundColor, for: .normal)
        setTitleColor(style.titleColor, for: .selected)
    }

    override func setBackgroundColor() {
        if isSelected {
            super.setBackgroundColor()
            borderWidth = 0
        } else {
            backgroundColor = nil
            borderColor = isEnabled ? style.backgroundColor : KDriveCoreAsset.buttonDisabledBackgroundColor.color
            borderWidth = 1
        }
    }
}
