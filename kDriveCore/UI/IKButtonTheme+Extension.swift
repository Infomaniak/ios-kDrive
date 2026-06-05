/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2026 Infomaniak Network SA

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

import DesignSystem
import InfomaniakCoreSwiftUI
import kDriveResources
import SwiftUI

public extension IKButtonTheme {
    static let drive = IKButtonTheme(
        primary: KDriveResourcesAsset.infomaniakColor.swiftUIColor,
        secondary: .white,
        tertiary: KDriveResourcesAsset.backgroundCardViewColor.swiftUIColor,
        disabledPrimary: KDriveResourcesAsset.buttonDisabledBackgroundColor.swiftUIColor,
        disabledSecondary: KDriveResourcesAsset.buttonDisabledBackgroundColor.swiftUIColor,
        error: KDriveResourcesAsset.binColor.swiftUIColor,
        smallFont: Font(UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 14), weight: .medium)),
        mediumFont: Font(UIFont.systemFont(ofSize: UIFontMetrics.default.scaledValue(for: 16), weight: .medium)),
        cornerRadius: UIConstants.Button.cornerRadius
    )
}
