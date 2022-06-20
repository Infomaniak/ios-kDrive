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
import MaterialOutlinedTextField
import UIKit

public extension MaterialOutlinedTextField {
    func setInfomaniakColors() {
        let textColor = KDriveResourcesAsset.titleColor.color
        let normalLabelColor = UIColor.placeholderText
        let normalBorderColor = KDriveResourcesAsset.borderColor.color
        let editingColor = KDriveResourcesAsset.infomaniakColor.color
        let disabledAlpha = 0.6

        let normalColorModel = ColorModel(textColor: textColor, floatingLabelColor: normalLabelColor, normalLabelColor: normalLabelColor, outlineColor: normalBorderColor)
        let editingColorModel = ColorModel(textColor: textColor, floatingLabelColor: editingColor, normalLabelColor: editingColor, outlineColor: editingColor)
        let disabledColorModel = ColorModel(textColor: textColor.withAlphaComponent(disabledAlpha),
                                            floatingLabelColor: normalLabelColor.withAlphaComponent(disabledAlpha),
                                            normalLabelColor: normalLabelColor.withAlphaComponent(disabledAlpha),
                                            outlineColor: normalBorderColor.withAlphaComponent(disabledAlpha))

        setColorModel(normalColorModel, for: .normal)
        setColorModel(editingColorModel, for: .editing)
        setColorModel(disabledColorModel, for: .disabled)
    }

    func setHint(_ hint: String?) {
        placeholder = hint
        label.text = hint
    }

    func setClearButton() {
        let clearButton = UIButton(frame: rightViewRect(forBounds: bounds))
        clearButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        clearButton.addTarget(self, action: #selector(didTouchClearButton), for: .touchUpInside)
        clearButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16)
        clearButton.tintColor = KDriveResourcesAsset.infomaniakColor.color

        rightView = clearButton
        rightViewMode = .whileEditing
    }

    @objc private func didTouchClearButton() {
        text = ""
    }
}
