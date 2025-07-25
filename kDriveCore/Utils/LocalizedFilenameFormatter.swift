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
import kDriveResources

public extension File {
    var formattedLocalizedName: String {
        return Self.LocalizedFilenameFormatter().format(self)
    }

    struct LocalizedFilenameFormatter: Foundation.FormatStyle, Codable, Equatable, Hashable {
        public func format(_ value: File) -> String {
            switch value.visibility {
            case .root, .isSharedSpace, .isTeamSpaceFolder, .isInTeamSpaceFolder, .isInSharedSpace:
                return value.name
            case .isPrivateSpace:
                return KDriveResourcesStrings.Localizable.localizedFilenamePrivateTeamSpace
            case .isTeamSpace:
                return KDriveResourcesStrings.Localizable.localizedFilenameTeamSpace
            case nil:
                return value.name
            }
        }
    }
}
