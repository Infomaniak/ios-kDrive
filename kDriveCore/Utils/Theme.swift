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

public enum Theme: String, CaseIterable {
    case light
    case dark
    case system

    public var interfaceStyle: UIUserInterfaceStyle {
        let styles: [Theme: UIUserInterfaceStyle] = [
            .light: .light,
            .dark: .dark,
            .system: .unspecified
        ]
        return styles[self] ?? .unspecified
    }

    public var title: String {
        switch self {
        case .light:
            return KDriveResourcesStrings.Localizable.themeSettingsLightLabel
        case .dark:
            return KDriveResourcesStrings.Localizable.themeSettingsDarkLabel
        case .system:
            return KDriveResourcesStrings.Localizable.themeSettingsSystemLabel
        }
    }

    public var selectionTitle: String {
        switch self {
        case .light, .dark:
            return title
        case .system:
            return KDriveResourcesStrings.Localizable.themeSettingsSystemDefaultLabel
        }
    }
}
