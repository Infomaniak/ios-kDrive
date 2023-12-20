//
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
import kDriveCore

extension NSFileProviderSyncAnchor {
    struct DatedCursor: Codable {
        let cursor: String
        let responseAt: Date
    }

    init?(_ cursor: FileCursor?) {
        guard let cursor else {
            return nil
        }
        let jsonEncoder = JSONEncoder()
        guard let datedCursorData = try? jsonEncoder.encode(DatedCursor(cursor: cursor, responseAt: Date())) else {
            return nil
        }

        self.init(datedCursorData)
    }

    var toDatedCursor: DatedCursor? {
        let jsonDecoder = JSONDecoder()
        guard let cursor = try? jsonDecoder.decode(DatedCursor.self, from: rawValue) else {
            return nil
        }

        return cursor
    }
}
