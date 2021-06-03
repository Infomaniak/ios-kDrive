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

    @objc public dynamic var objectId: String = ""
    public var account = List<Int>()
    public var drive = List<Int>()
    public var internalUsers = List<Int>()
    public var externalUsers = List<Int>()

    public override init() {
    }

    enum CodingKeys: String, CodingKey {
        case account
        case drive
        case internalUsers = "internal"
        case externalUsers = "external"
    }

    public override static func primaryKey() -> String? {
        return "objectId"
    }

}
public enum DrivePack: String, Codable {
    case solo
    case pro
    case team
    case free
}

public class DrivePackFunctionality: Object, Codable {
    @objc public dynamic var objectId: String = ""
    @objc public dynamic var versionsNumber: Int = 0
    @objc public dynamic var dropbox: Bool = false
    @objc public dynamic var versioning: Bool = false
    @objc public dynamic var manageRight: Bool = false
    @objc public dynamic var hasTeamSpace: Bool = false
    @objc public dynamic var versionsKeptForDays: Int = 0

    public override init() {
    }

    enum CodingKeys: String, CodingKey {
        case dropbox
        case versioning
        case manageRight = "manage_right"
        case hasTeamSpace = "has_team_space"
        case versionsNumber = "number_of_versions"
        case versionsKeptForDays = "versions_kept_for_days"
    }

    public override static func primaryKey() -> String? {
        return "objectId"
    }

}

public class DrivePreferences: Object, Codable {
    @objc public dynamic var objectId: String = ""
    @objc public dynamic var color: String
    @objc public dynamic var hide: Bool

    public override init() {
        color = "#0098FF"
        hide = false
    }

    public override static func primaryKey() -> String? {
        return "objectId"
    }

    enum CodingKeys: String, CodingKey {
        case color
        case hide
    }
}

public class Drive: Object, Codable {

    @objc public dynamic var objectId: String = ""
    /*
     User data
     */
    @objc public dynamic var canAddUser: Bool = false
    @objc public dynamic var canCreateTeamFolder: Bool = false
    @objc public dynamic var hasTechnicalRight: Bool = false
    @objc public dynamic var name: String = ""
    @objc private dynamic var _preferences: DrivePreferences?
    @objc public dynamic var role: String = ""

    /*
     Drive data
     */
    /// Account id of the drive CREATOR
    @objc public dynamic var accountId: Int = -1
    @objc public dynamic var id: Int = -1
    @objc private dynamic var _pack: String = ""
    @objc public dynamic var packFunctionality: DrivePackFunctionality?
    @objc public dynamic var sharedWithMe: Bool = false
    @objc public dynamic var size: Int64 = 0
    @objc public dynamic var usedSize: Int64 = 0
    @objc private dynamic var _users: DriveUsersCategories? = DriveUsersCategories()
    @objc public dynamic var maintenance: Bool = false
    @objc public dynamic var userId: Int = 0 {
        didSet {
            let objectId = DriveInfosManager.getObjectId(driveId: id, userId: userId)
            self.objectId = objectId
            _preferences?.objectId = objectId
            packFunctionality?.objectId = objectId
            _users?.objectId = objectId
        }
    }

    public override init() {
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

    public override static func primaryKey() -> String? {
        return "objectId"
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
