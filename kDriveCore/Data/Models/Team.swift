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

public class Team: Object, Codable {
    @Persisted(primaryKey: true) public var id: Int
    @Persisted public var details: List<TeamDetail>
    @Persisted public var users: List<Int>
    @Persisted public var name: String
    @Persisted public var color: Int
    public var right: UserPermission?

    public var isAllUsers: Bool {
        return id == 0
    }

    public var colorHex: String {
        guard !isAllUsers else { return "#4051b5" }
        let colors = [
            "#F44336",
            "#E91E63",
            "#9C26B0",
            "#673AB7",
            "#4051B5",
            "#4BAF50",
            "#009688",
            "#00BCD4",
            "#02A9F4",
            "#2196F3",
            "#8BC34A",
            "#CDDC3A",
            "#FFC10A",
            "#FF9802",
            "#607D8B",
            "#9E9E9E",
            "#795548"
        ]
        return color < colors.count ? colors[color] : "#E91E63"
    }

    override public init() {}

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        super.init()
        id = try values.decode(Int.self, forKey: .id)
        details = try values.decodeIfPresent(List<TeamDetail>.self, forKey: .details) ?? List<TeamDetail>()
        users = try values.decodeIfPresent(List<Int>.self, forKey: .users) ?? List<Int>()
        name = try values.decode(String.self, forKey: .name)
        color = try values.decode(Int.self, forKey: .color)
        right = try values.decodeIfPresent(UserPermission.self, forKey: .right)
    }

    public func usersCount(in drive: Drive) -> Int {
        let detail = details.first { $0.driveId == drive.id }
        return detail?.usersCount ?? users.filter { drive.users.internalUsers.contains($0) }.count
    }
}

extension Team: Shareable {
    public var userId: Int? {
        return nil
    }

    public var shareableName: String {
        return isAllUsers ? KDriveCoreStrings.Localizable.allAllDriveUsers : name
    }
}

extension Team: Comparable {
    public static func < (lhs: Team, rhs: Team) -> Bool {
        return lhs.isAllUsers || lhs.name.lowercased() < rhs.name.lowercased()
    }
}

public class TeamDetail: Object, Codable {
    @Persisted public var driveId: Int
    @Persisted public var usersCount: Int

    enum CodingKeys: String, CodingKey {
        case driveId = "drive_id"
        case usersCount = "users_count"
    }
}
