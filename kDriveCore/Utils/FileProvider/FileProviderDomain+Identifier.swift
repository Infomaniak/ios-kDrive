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

import FileProvider
import Foundation

public extension NSFileProviderDomain {
    private typealias DriveIdAndUserId = (driveId: Int, userId: Int)

    private var userAndDrive: DriveIdAndUserId? {
        let identifiers = identifier.rawValue.components(separatedBy: "_")

        guard let driveIdString = identifiers[safe: 0],
              let usedIdString = identifiers[safe: 1],
              let driveId = Int(driveIdString),
              let usedId = Int(usedIdString) else {
            return nil
        }

        return (driveId, usedId)
    }

    var userId: Int? {
        userAndDrive?.userId
    }

    var driveId: Int? {
        userAndDrive?.driveId
    }
}
