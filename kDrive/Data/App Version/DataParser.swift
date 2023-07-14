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

import Foundation

struct DataParser {
    /// Checks to see if the App Store version of the app is newer than the installed version.
    ///
    /// - Parameters:
    ///   - installedVersion: The installed version of the app.
    ///   - appStoreVersion: The App Store version of the app.
    /// - Returns: `true` if the App Store version is newer. Otherwise, `false`.
    static func isAppStoreVersionNewer(installedVersion: String?, appStoreVersion: String?) -> Bool {
        guard let installedVersion,
              let appStoreVersion,
              installedVersion.compare(appStoreVersion, options: .numeric) == .orderedAscending else {
            return false
        }

        return true
    }
}
