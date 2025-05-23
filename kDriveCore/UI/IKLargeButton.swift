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

// swiftformat:disable redundanttype
@IBDesignable public class IKLargeButton: UIButton {
    /// Toggle shadow elevation.
    @IBInspectable public var elevated: Bool = false {
        didSet { setElevation() }
    }

    /// Set elevation value.
    @IBInspectable public var elevation: Int = 1 {
        didSet { setElevation() }
    }

    /// Set button style.
    @IBInspectable public var styleName: String = Style.primaryButton.rawValue {
        didSet { setUpButton() }
    }

    /// Set button style.
    public var style: Style {
        get {
            return Style(rawValue: styleName) ?? .primaryButton
        }
        set {
            styleName = newValue.rawValue
        }
    }

    public var disabledBackgroundColor = KDriveResourcesAsset.buttonDisabledBackgroundColor.color

    public struct Style: RawRepresentable {
        public var titleFont: UIFont
        public var titleColor: UIColor
        public var backgroundColor: UIColor

        public static let primaryButton = Style(
            titleFont: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium),
            titleColor: .white,
            backgroundColor: KDriveResourcesAsset.infomaniakColor.color,
            rawValue: "primaryButton"
        )
        public static let secondaryButton = Style(
            titleFont: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium),
            titleColor: KDriveResourcesAsset.titleColor.color,
            backgroundColor: KDriveResourcesAsset.backgroundColor.color,
            rawValue: "secondaryButton"
        )
        public static let whiteButton = Style(
            titleFont: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium),
            titleColor: KDriveResourcesAsset.titleColor.color,
            backgroundColor: KDriveResourcesAsset.backgroundCardViewColor.color,
            rawValue: "whiteButton"
        )
        public static let plainButton = Style(
            titleFont: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium),
            titleColor: KDriveResourcesAsset.infomaniakColor.color,
            backgroundColor: .clear,
            rawValue: "plainButton"
        )

        static let allValues = [primaryButton, secondaryButton, whiteButton, plainButton]

        public var rawValue: String

        init(titleFont: UIFont, titleColor: UIColor, backgroundColor: UIColor, rawValue: RawValue) {
            self.titleFont = titleFont
            self.titleColor = titleColor
            self.backgroundColor = backgroundColor
            self.rawValue = rawValue
        }

        public init?(rawValue: String) {
            if let style = Style.allValues.first(where: { $0.rawValue == rawValue }) {
                self = style
            } else {
                return nil
            }
        }
    }

    override public var isEnabled: Bool {
        didSet { setEnabled() }
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
        layer.cornerRadius = UIConstants.Button.cornerRadius

        // Set text font & color
        titleLabel?.font = style.titleFont
        setTitleColor(style.titleColor, for: .normal)
        setTitleColor(KDriveResourcesAsset.buttonDisabledTitleColor.color, for: .disabled)

        setBackgroundColor()
        setElevation()
    }

    func setBackgroundColor() {
        tintColor = isEnabled ? style.backgroundColor : disabledBackgroundColor
        backgroundColor = isEnabled ? style.backgroundColor : disabledBackgroundColor
    }

    func setElevation() {
        if elevated && isEnabled {
            addShadow(elevation: Double(elevation))
        } else {
            layer.shadowColor = nil
            layer.shadowOpacity = 0.0
        }
    }

    func setEnabled() {
        setElevation()
        setBackgroundColor()
    }
}

// swiftformat:enable redundanttype
