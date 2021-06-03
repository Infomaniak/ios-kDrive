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
import RealmSwift

public class Tag: Object, Codable {
    @objc public dynamic var id: Int
    @objc public dynamic var name: String
    @objc public dynamic var color: Int
    public var right: UserPermission?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case right
    }

    public func isAllDriveUsersTag() -> Bool {
        return id == 0
    }

    public func getColor() -> String {
        let colors = [
            "#4051B5",
            "#30ABFF",
            "#ED2C6E",
            "#FFB11B",
            "#029688",
            "#7974B4",
            "#3CB572",
            "#05C2E7",
            "#D9283A",
            "#3990BB"
        ]
        return color < 10 ? colors[color] : "#30ABFF"
    }

    public override class func primaryKey() -> String? {
        return "id"
    }

}
