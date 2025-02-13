/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

enum DriveInitWith: String, CaseIterable {
    case drives
    case users
    case teams
    case teamsUsers = "teams.users"
    case teamsUsersCount = "teams.users_count"
    case drivesCapabilities = "drives.capabilities"
    case drivesPreferences = "drives.preferences"
    case drivesPack = "drives.pack"
    case drivesPackCapabilities = "drives.pack.capabilities"
    case drivesPackLimits = " drives.pack.limits"
    case drivesLimits = "drive.limits"
    case drivesSettings = "drives.settings"
    case drivesKSuite = "drives.k_suite"
    case drivesTags = "drives.tags"
    case drivesRights = "drives.rights"
    case drivesCategories = "drives.categories"
    case drivesCategoriesPermissions = "drives.categories_permissions"
    case drivesUsers = "drives.users"
    case drivesTeams = "drives.teams"
    case drivesRewind = "drives.rewind"
    case drivesAccount = "drives.account"
    case quota = "drives.quota"
}

extension [DriveInitWith] {
    func toQueryItem() -> URLQueryItem {
        URLQueryItem(
            name: "with",
            value: map(\.rawValue).joined(separator: ",")
        )
    }
}
