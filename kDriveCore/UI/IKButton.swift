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

import InfomaniakCoreCommonUI
import UIKit

@IBDesignable public class IKButton: UIButton {
    /// Set button style.
    @IBInspectable public var styleName: String = TextStyle.action.rawValue {
        didSet { setUpButton() }
    }

    /// Set button style.
    public var style: TextStyle {
        get {
            return TextStyle(rawValue: styleName) ?? .action
        }
        set {
            styleName = newValue.rawValue
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpButton()
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpButton()
    }

    func setUpButton() {
        titleLabel?.font = style.font
        tintColor = style.color
    }
}
