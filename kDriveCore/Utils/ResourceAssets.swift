/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import kDriveResources
import UIKit

/// Resolves Interface Builder assets from the shared resources framework in the app and extensions.
private enum ResourceAssets {
    static func image(_ name: String?) -> UIImage? {
        name.flatMap {
            UIImage(named: $0 == "folder-fill" ? "folder-filled" : $0,
                    in: KDriveResourcesResources.bundle, compatibleWith: nil)
        }
    }

    static func color(_ name: String?) -> UIColor? {
        let aliases = ["backgroundCardView": "backgroundCardViewColor", "borderColor": "BorderColor"]
        return name.flatMap { UIColor(named: aliases[$0] ?? $0, in: KDriveResourcesResources.bundle, compatibleWith: nil) }
    }
}

public extension UIView {
    @IBInspectable var resourceBackgroundColorName: String? {
        get { nil }
        set { backgroundColor = ResourceAssets.color(newValue) }
    }

    @IBInspectable var resourceTintColorName: String? {
        get { nil }
        set { tintColor = ResourceAssets.color(newValue) }
    }

    @IBInspectable var resourceBorderColorName: String? {
        get { nil }
        set { layer.borderColor = ResourceAssets.color(newValue)?.cgColor }
    }
}

public extension UIImageView {
    @IBInspectable var resourceImageName: String? {
        get { nil }
        set { image = ResourceAssets.image(newValue) }
    }
}

public extension UIBarItem {
    @IBInspectable var resourceImageName: String? {
        get { nil }
        set { image = ResourceAssets.image(newValue) }
    }
}

public extension UIButton {
    @IBInspectable var resourceNormalImageName: String? {
        get { nil }
        set { setImage(ResourceAssets.image(newValue), for: .normal) }
    }

    @IBInspectable var resourceSelectedImageName: String? {
        get { nil }
        set { setImage(ResourceAssets.image(newValue), for: .selected) }
    }

    @IBInspectable var resourceHighlightedImageName: String? {
        get { nil }
        set { setImage(ResourceAssets.image(newValue), for: .highlighted) }
    }

    @IBInspectable var resourceDisabledImageName: String? {
        get { nil }
        set { setImage(ResourceAssets.image(newValue), for: .disabled) }
    }

    @IBInspectable var resourceNormalTitleColorName: String? {
        get { nil }
        set { setTitleColor(ResourceAssets.color(newValue), for: .normal) }
    }

    @IBInspectable var resourceHighlightedTitleColorName: String? {
        get { nil }
        set { setTitleColor(ResourceAssets.color(newValue), for: .highlighted) }
    }

    @IBInspectable var resourceDisabledTitleColorName: String? {
        get { nil }
        set { setTitleColor(ResourceAssets.color(newValue), for: .disabled) }
    }
}

public extension UILabel {
    @IBInspectable var resourceTextColorName: String? {
        get { nil }
        set { textColor = ResourceAssets.color(newValue) }
    }
}

public extension UITextField {
    @IBInspectable var resourceTextColorName: String? {
        get { nil }
        set { textColor = ResourceAssets.color(newValue) }
    }
}

public extension UITextView {
    @IBInspectable var resourceTextColorName: String? {
        get { nil }
        set { textColor = ResourceAssets.color(newValue) }
    }
}

public extension UISwitch {
    @IBInspectable var resourceOnTintColorName: String? {
        get { nil }
        set { onTintColor = ResourceAssets.color(newValue) }
    }
}

public extension UISegmentedControl {
    @IBInspectable var resourceSelectedSegmentTintColorName: String? {
        get { nil }
        set { selectedSegmentTintColor = ResourceAssets.color(newValue) }
    }
}

public extension UIProgressView {
    @IBInspectable var resourceProgressTintColorName: String? {
        get { nil }
        set { progressTintColor = ResourceAssets.color(newValue) }
    }
}

public extension UIActivityIndicatorView {
    @IBInspectable var resourceColorName: String? {
        get { nil }
        set { color = ResourceAssets.color(newValue) }
    }
}

public extension UISlider {
    @IBInspectable var resourceMaximumTrackTintColorName: String? {
        get { nil }
        set { maximumTrackTintColor = ResourceAssets.color(newValue) }
    }
}
