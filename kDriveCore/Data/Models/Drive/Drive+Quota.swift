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

public final class Quota: EmbeddedObject, Codable {
    @Persisted public var current: Int?
    @Persisted public var max: Int

    override public init() {
        // Required by Realm
        super.init()
    }
}

public final class DriveQuota: EmbeddedObject, Codable {
    @Persisted public var dropbox: Quota?
    @Persisted public var sharedLink: Quota?

    enum CodingKeys: String, CodingKey {
        case dropbox
        case sharedLink
    }

    override public init() {
        // Required by Realm
        super.init()
    }
}

public extension Drive {
    var dropboxQuotaExceeded: Bool {
        guard let quota, let dropbox = quota.dropbox else { return false }
        return dropbox.current ?? 0 >= dropbox.max
    }

    var sharedLinkQuotaExceeded: Bool {
        guard let quota, let sharedLink = quota.sharedLink else { return false }
        return sharedLink.current ?? 0 >= sharedLink.max
    }

    var sharedLinkKSuiteRestricted: Bool {
        return pack.kSuiteProUpgradePath != nil && sharedLinkQuotaExceeded
    }
}
