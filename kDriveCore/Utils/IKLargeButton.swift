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

@IBDesignable public class IKLargeButton: UIButton {

    /// Toggle shadow elevation.
    @IBInspectable public var elevated: Bool = false {
        didSet { setElevation() }
    }

    /// Set elevation value.
    @IBInspectable public var elevation: Int = 1 {
        didSet { setElevation() }
    }
    
    /// Set title style
    @IBInspectable public var style: String = Style.primaryButton.rawValue {
        didSet {
            setUpButton()
        }
    }
    
    public struct Style: RawRepresentable {

        var titleFont: UIFont
        var titleColor: UIColor
        var backgroundColor: UIColor

        static let primaryButton = Style(titleFont: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium), titleColor: .white, backgroundColor: KDriveCoreAsset.infomaniakColor.color, rawValue: "primaryButton")
        static let secondaryButton = Style(titleFont: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium), titleColor: KDriveCoreAsset.titleColor.color, backgroundColor: KDriveCoreAsset.backgroundColor.color, rawValue: "secondaryButton")

        static let allValues = [primaryButton, secondaryButton]

        public typealias RawValue = String
        public var rawValue: String

        internal init(titleFont: UIFont, titleColor: UIColor, backgroundColor: UIColor, rawValue: RawValue) {
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

    public override var isEnabled: Bool {
        didSet { setEnabled() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpButton()
    }

    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpButton()
    }

    func setUpButton() {
        layer.cornerRadius = 10

        guard let style = Style(rawValue: style) else {
            return
        }
        titleLabel?.font = style.titleFont
        setTitleColor(style.titleColor, for: .normal)
        setTitleColor(KDriveCoreAsset.buttonDisabledTitleColor.color, for: .disabled)

        setBackgroundColor()
        setElevation()
    }
    
    func setBackgroundColor() {
        guard let style = Style(rawValue: style) else {
            return
        }
        backgroundColor = isEnabled ? style.backgroundColor : KDriveCoreAsset.buttonDisabledBackgroundColor.color
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
