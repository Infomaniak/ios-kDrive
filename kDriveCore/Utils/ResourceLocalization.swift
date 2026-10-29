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

public extension UILabel {
    @IBInspectable var xibLocKey: String? {
        get { nil }
        set { text = newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) } }
    }
}

public extension UIButton {
    @IBInspectable var xibLocKey: String? {
        get { nil }
        set { setTitle(
            newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) },
            for: .normal
        ) }
    }

    @IBInspectable var xibLocKeyDisabled: String? {
        get { nil }
        set { setTitle(
            newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) },
            for: .disabled
        ) }
    }
}

public extension UINavigationItem {
    @IBInspectable var xibLocKey: String? {
        get { nil }
        set { title = newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) } }
    }
}

public extension UIBarItem {
    @IBInspectable var xibLocKey: String? {
        get { nil }
        set { title = newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) } }
    }
}

public extension UISegmentedControl {
    @IBInspectable var xibLocKeys: String? {
        get { nil }
        set {
            for (index, key) in (newValue?.components(separatedBy: ",") ?? []).enumerated() {
                setTitle(
                    KDriveResourcesResources.bundle.localizedString(forKey: key, value: nil, table: nil),
                    forSegmentAt: index
                )
            }
        }
    }
}

public extension UITextField {
    @IBInspectable var xibPlaceholderLocKey: String? {
        get { nil }
        set { placeholder = newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) } }
    }
}

public extension UITextView {
    @IBInspectable var xibLocKey: String? {
        get { nil }
        set { text = newValue.map { KDriveResourcesResources.bundle.localizedString(forKey: $0, value: nil, table: nil) } }
    }
}
