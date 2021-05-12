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

public struct TextStyle: RawRepresentable {

    var font: UIFont
    var color: UIColor

    static let header2 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 18), weight: .semibold), color: KDriveCoreAsset.titleColor.color, rawValue: "header2")
    static let subtitle1 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .regular), color: KDriveCoreAsset.titleColor.color, rawValue: "subtitle1")
    static let subtitle2 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .medium), color: KDriveCoreAsset.titleColor.color, rawValue: "subtitle2")
    static let body1 = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: KDriveCoreAsset.titleColor.color, rawValue: "body1")
    static let caption = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 12), weight: .regular), color: KDriveCoreAsset.primaryTextColor.color, rawValue: "caption")
    static let header1FileInfo = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 28), weight: .bold), color: .white, rawValue: "header1FileInfo")
    static let captionFileInfo = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 12), weight: .regular), color: .white, rawValue: "captionFileInfo")
    static let bodyFileInfo = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: .white, rawValue: "bodyFileInfo")
    static let action = TextStyle(font: UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .regular), color: KDriveCoreAsset.infomaniakColor.color, rawValue: "buttonLink")

    static let allValues = [header2, subtitle1, subtitle2, body1, caption, header1FileInfo, captionFileInfo, bodyFileInfo, action]

    public typealias RawValue = String
    public var rawValue: String

    internal init(font: UIFont, color: UIColor, rawValue: RawValue) {
        self.font = font
        self.color = color
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        if let style = TextStyle.allValues.first(where: { $0.rawValue == rawValue }) {
            self = style
        } else {
            return nil
        }
    }
}

@IBDesignable public class IKLabel: UILabel {

    /// Set label style.
    @IBInspectable public var styleName: String = TextStyle.body1.rawValue {
        didSet { setUpLabel() }
    }

    /// Set label style.
    public var style: TextStyle {
        get {
            return TextStyle(rawValue: styleName) ?? .body1
        }
        set {
            styleName = newValue.rawValue
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpLabel()
    }

    public override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setUpLabel()
    }

    func setUpLabel() {
        font = style.font
        textColor = style.color
    }
}
