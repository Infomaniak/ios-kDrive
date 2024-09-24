/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

public enum SyncMod: String, CaseIterable {
    case onlyWifi
    case wifiAndMobileData

//    public var interfaceStyle: UIUserInterfaceStyle {
//        let styles: [Theme: UIUserInterfaceStyle] = [
//            .light: .light,
//            .dark: .dark,
//            .system: .unspecified
//        ]
//        return styles[self] ?? .unspecified
//    }

    public var title: String {
        switch self {
        case .onlyWifi:
            return KDriveResourcesStrings.Localizable.themeSettingsLightLabel
        case .wifiAndMobileData:
            return KDriveResourcesStrings.Localizable.themeSettingsDarkLabel
        }
    }

    public var selectionTitle: String {
        switch self {
        case .onlyWifi:
            return KDriveResourcesStrings.Localizable.settingsOnlyWifiSyncDescription
        case .wifiAndMobileData:
            return "Wifi et données mobiles (à changer)"
        }
    }
}
