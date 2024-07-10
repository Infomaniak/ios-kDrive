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

public enum LegalEntityType: String {
    case individual
    case publicBody
    case company
    case restrict
    case unknown
}

public class DriveAccount: EmbeddedObject, Codable {
    @Persisted public var id: Int
    @Persisted public var name: String
    @Persisted private var _legalEntityType: String

    public var legalEntityType: LegalEntityType {
        return LegalEntityType(rawValue: _legalEntityType) ?? .unknown
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case _legalEntityType = "legal_entity_type"
    }
}
