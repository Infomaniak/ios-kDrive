/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import InfomaniakCore
import RealmSwift

public final class DriveQuota: EmbeddedObject, Codable {
    @Persisted public var dropbox: Int?
    @Persisted public var sharedLink: Int?

    enum CodingKeys: String, CodingKey {
        case dropbox
        case sharedLink = "shared_link"
    }

    override public init() {
        // Required by Realm
        super.init()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dropboxString = try container.decode(String.self, forKey: .dropbox)
        if let dropbox = Int(dropboxString) {
            self.dropbox = dropbox
        }

        let sharedLinkString = try container.decode(String.self, forKey: .sharedLink)
        if let sharedLink = Int(sharedLinkString) {
            self.sharedLink = sharedLink
        }
    }
}

extension Drive {
    var dropboxQuotaExceeded: Bool {
        // TODO: Use real quota data
        true
    }

    var sharedLinkQuotaExceeded: Bool {
        // TODO: Use real quota data
        true
    }
}
