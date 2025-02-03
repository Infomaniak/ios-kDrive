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
import RealmSwift

public enum DrivePackId: String {
    case solo
    case team
    case pro
    case free
    case kSuiteStandard = "ksuite_standard"
    case kSuitePro = "ksuite_pro"
    case kSuiteEntreprise = "ksuite_entreprise"
    case myKSuite = "my_ksuite"
    case myKSuitePlus = "my_ksuite_plus"
}

public class DrivePack: EmbeddedObject, Codable {
    @Persisted public var id = 0
    @Persisted public var name = ""
    @Persisted var _capabilities: DrivePackCapabilities?

    public var capabilities: DrivePackCapabilities {
        return _capabilities ?? DrivePackCapabilities()
    }

    /// Convenience enum bridge
    public var drivePackId: DrivePackId? {
        DrivePackId(rawValue: name)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case _capabilities = "capabilities"
    }
}
