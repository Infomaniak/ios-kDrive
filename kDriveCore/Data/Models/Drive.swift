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
import InfomaniakCore
import RealmSwift

public class DriveResponse: Codable {
    public let drives: DriveList
    public let users: [Int: DriveUser]
    public let tags: [Tag]
    public let ipsToken: IPSToken

    enum CodingKeys: String, CodingKey {
        case drives
        case users
        case tags
        case ipsToken = "ips_token"
    }
}

public class DriveList: Codable {
    public let main: [Drive]
    public let sharedWithMe: [Drive]

    enum CodingKeys: String, CodingKey {
        case main
        case sharedWithMe = "shared_with_me"
    }
}

public class DriveUsersCategories: Object, Codable {
    @Persisted(primaryKey: true) public var objectId: String = ""
    @Persisted public var account: List<Int>
    @Persisted public var drive: List<Int>
    @Persisted public var internalUsers: List<Int>
    @Persisted public var externalUsers: List<Int>

    enum CodingKeys: String, CodingKey {
        case account
        case drive
        case internalUsers = "internal"
        case externalUsers = "external"
    }
}

public enum DrivePack: String, Codable {
    case solo
    case pro
    case team
    case free
}

public class DrivePackFunctionality: Object, Codable {
    @Persisted(primaryKey: true) public var objectId: String = ""
    @Persisted public var versionsNumber: Int = 0
    @Persisted public var dropbox = false
    @Persisted public var versioning = false
    @Persisted public var manageRight = false
    @Persisted public var hasTeamSpace = false
    @Persisted public var versionsKeptForDays: Int = 0

    enum CodingKeys: String, CodingKey {
        case dropbox
        case versioning
        case manageRight = "manage_right"
        case hasTeamSpace = "has_team_space"
        case versionsNumber = "number_of_versions"
        case versionsKeptForDays = "versions_kept_for_days"
    }
}

public class DrivePreferences: Object, Codable {
    @Persisted(primaryKey: true) public var objectId: String = ""
    @Persisted public var color: String
    @Persisted public var hide: Bool

    override public init() {
        color = "#0098FF"
        hide = false
    }

    enum CodingKeys: String, CodingKey {
        case color
        case hide
    }
}

public class Drive: Object, Codable {
    @Persisted(primaryKey: true) public var objectId: String = ""
    /*
     User data
     */
    @Persisted public var canAddUser = false
    @Persisted public var canCreateTeamFolder = false
    @Persisted public var hasTechnicalRight = false
    @Persisted public var name: String = ""
    @Persisted private var _preferences: DrivePreferences?
    @Persisted public var role: String = ""

    /*
     Drive data
     */
    /// Account id of the drive CREATOR
    @Persisted public var accountId: Int = -1
    @Persisted public var id: Int = -1
    @Persisted private var _pack: String = ""
    @Persisted public var packFunctionality: DrivePackFunctionality?
    @Persisted public var sharedWithMe = false
    @Persisted public var size: Int64 = 0
    @Persisted public var usedSize: Int64 = 0
    @Persisted private var _users: DriveUsersCategories? = DriveUsersCategories()
    @Persisted public var maintenance = false
    @Persisted public var userId: Int = 0 {
        didSet {
            let objectId = DriveInfosManager.getObjectId(driveId: id, userId: userId)
            self.objectId = objectId
            _preferences?.objectId = objectId
            packFunctionality?.objectId = objectId
            _users?.objectId = objectId
        }
    }

    public var pack: DrivePack {
        return DrivePack(rawValue: _pack)!
    }

    public var preferences: DrivePreferences {
        return _preferences ?? DrivePreferences()
    }

    public var users: DriveUsersCategories {
        return _users ?? DriveUsersCategories()
    }

    public var isUserAdmin: Bool {
        return role == "admin"
    }

    public var isProOrTeam: Bool {
        return pack == .pro || pack == .team
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try values.decode(Int.self, forKey: .accountId)
        id = try values.decode(Int.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        _pack = try values.decode(String.self, forKey: ._pack)
        role = try values.decode(String.self, forKey: .role)
        _preferences = try values.decode(DrivePreferences.self, forKey: ._preferences)
        _users = try values.decode(DriveUsersCategories.self, forKey: ._users)
        size = try values.decode(Int64.self, forKey: .size)
        usedSize = try values.decode(Int64.self, forKey: .usedSize)
        canAddUser = try values.decode(Bool.self, forKey: .canAddUser)
        packFunctionality = try values.decode(DrivePackFunctionality.self, forKey: .packFunctionality)
        hasTechnicalRight = try values.decode(Bool.self, forKey: .hasTechnicalRight)
        canCreateTeamFolder = try values.decode(Bool.self, forKey: .canCreateTeamFolder)
        maintenance = try values.decode(Bool.self, forKey: .maintenance)
    }

    override public init() {}

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case id
        case name
        case _pack = "pack"
        case role
        case _preferences = "preferences"
        case size
        case usedSize = "used_size"
        case _users = "users"
        case canAddUser = "can_add_user"
        case packFunctionality = "pack_functionality"
        case hasTechnicalRight = "has_technical_right"
        case canCreateTeamFolder = "can_create_team_folder"
        case maintenance
    }

    public static func == (lhs: Drive, rhs: Drive) -> Bool {
        return lhs.objectId == rhs.objectId
    }
}
