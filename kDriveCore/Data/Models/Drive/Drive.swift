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

@frozen public struct DriveResponse: Codable {
    public let drives: [Drive]
    public let users: [DriveUser]
    public let teams: [Team]
    public let ips: IPSToken
}

public final class DriveUsersCategories: EmbeddedObject, Codable {
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

public final class DriveTeamsCategories: EmbeddedObject, Codable {
    @Persisted public var account: List<Int>
    @Persisted public var drive: List<Int>
}

public enum MaintenanceReason: String, PersistableEnum, Codable {
    // ⚠️ For some reason PersistableEnum breaks something with key decoding, that's why we are explicitly writing snake case
    case notRenew = "not_renew"
    case demoEnd = "demo_end"
    case invoiceOverdue = "invoice_overdue"
    case technical
    case unknown

    public init(from decoder: any Decoder) throws {
        let singleKeyContainer = try decoder.singleValueContainer()
        let value = try singleKeyContainer.decode(String.self)

        self = MaintenanceReason(rawValue: value) ?? .unknown
    }
}

public class MaintenanceType: EmbeddedObject, Codable {
    @Persisted public var code: MaintenanceTypeValue
}

public enum MaintenanceTypeValue: String, PersistableEnum, Codable {
    // ⚠️ For some reason PersistableEnum breaks something with key decoding, that's why we are explicitly writing snake case
    case managerInMaintenance = "manager_in_maintenance"
    case managerIsBlocked = "manager_is_blocked"
    case moveNs = "move_ns"
    case moveSqlMaster = "move_sql_master"
    case moveSqlCluster = "move_sql_cluster"
    case rewind
    case upgradeSchema = "upgrade_schema"
    case hardDelete = "hard_delete"
    case asleep
    case wakingUp = "waking_up"
    case uninitializing
    case unknown

    public init(from decoder: any Decoder) throws {
        let singleKeyContainer = try decoder.singleValueContainer()
        let value = try singleKeyContainer.decode(String.self)

        self = MaintenanceTypeValue(rawValue: value) ?? .unknown
    }
}

public final class DrivePreferences: EmbeddedObject, Codable {
    @Persisted public var color = "#0098FF"
    @Persisted public var hide = false
}

public final class Drive: Object, Codable {
    @Persisted(primaryKey: true) public var objectId = UUID().uuidString
    /*
     User data
     */
    @Persisted public var rights: DriveRights?
    @Persisted public var name = ""
    @Persisted private var _preferences: DrivePreferences?
    @Persisted public var role = ""
    @Persisted public var _capabilities: DriveCapabilities?
    /*
     Drive data
     */
    /// Account id of the drive CREATOR
    @Persisted public var accountId: Int = -1
    @Persisted public var id: Int = -1
    @Persisted public var _pack: DrivePack?
    @Persisted public var sharedWithMe = false
    @Persisted public var size: Int64 = 0
    @Persisted public var usedSize: Int64 = 0
    @Persisted private var _users: DriveUsersCategories?
    @Persisted private var _teams: DriveTeamsCategories?
    @Persisted public var categories: List<Category>
    @Persisted private var _categoryRights: CategoryRights?
    @Persisted public var inMaintenance = false
    @Persisted public var maintenanceReason: MaintenanceReason?
    @Persisted public var maintenanceTypes: List<MaintenanceType>
    @Persisted public var updatedAt: Date
    @Persisted public var _account: DriveAccount?
    @Persisted public var quota: DriveQuota?
    /// Is manager admin.
    @Persisted public var accountAdmin = false
    /// Was product purchased with in-app purchase.
    @Persisted public var isInAppSubscription = false
    @Persisted public var userId = 0 {
        didSet {
            objectId = DriveInfosManager.getObjectId(driveId: id, userId: userId)
        }
    }

    public var isAsleep: Bool {
        return maintenanceTypes.contains { $0.code == .asleep }
    }

    public var preferences: DrivePreferences {
        return _preferences ?? DrivePreferences()
    }

    public var users: DriveUsersCategories {
        return _users ?? DriveUsersCategories()
    }

    public var teams: DriveTeamsCategories {
        return _teams ?? DriveTeamsCategories()
    }

    public var categoryRights: CategoryRights {
        return _categoryRights ?? CategoryRights()
    }

    public var capabilities: DriveCapabilities {
        return _capabilities ?? DriveCapabilities()
    }

    public var account: DriveAccount {
        return _account ?? DriveAccount()
    }

    public var pack: DrivePack {
        return _pack ?? DrivePack()
    }

    public var isUserAdmin: Bool {
        return role == "admin"
    }

    public var isDriveUser: Bool {
        return role != "none" && role != "external"
    }

    public var isFreePack: Bool {
        return pack.drivePackId == .free || pack.drivePackId == .myKSuite
    }

    public var isInTechnicalMaintenance: Bool {
        return inMaintenance && maintenanceReason == .technical
    }

    public required init(from decoder: Decoder) throws {
        super.init()
        // primary key is set as default value

        let values = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try values.decode(Int.self, forKey: .accountId)
        id = try values.decode(Int.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        _pack = try values.decode(DrivePack.self, forKey: ._pack)
        role = try values.decode(String.self, forKey: .role)
        _preferences = try values.decode(DrivePreferences.self, forKey: ._preferences)
        _users = try values.decode(DriveUsersCategories.self, forKey: ._users)
        _teams = try values.decode(DriveTeamsCategories.self, forKey: ._teams)
        categories = try values.decode(List<Category>.self, forKey: .categories)
        _categoryRights = try values.decode(CategoryRights.self, forKey: ._categoryRights)
        size = try values.decode(Int64.self, forKey: .size)
        usedSize = try values.decode(Int64.self, forKey: .usedSize)
        _capabilities = try values.decode(DriveCapabilities.self, forKey: ._capabilities)
        rights = try values.decode(DriveRights.self, forKey: .rights)
        inMaintenance = try values.decode(Bool.self, forKey: .inMaintenance)
        maintenanceReason = try values.decodeIfPresent(MaintenanceReason.self, forKey: .maintenanceReason)
        maintenanceTypes = try values
            .decodeIfPresent(List<MaintenanceType>.self, forKey: .maintenanceTypes) ?? List<MaintenanceType>()
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        _account = try values.decode(DriveAccount.self, forKey: ._account)
        accountAdmin = try values.decode(Bool.self, forKey: .accountAdmin)
        isInAppSubscription = try values.decode(Bool.self, forKey: .isInAppSubscription)
        quota = try values.decodeIfPresent(DriveQuota.self, forKey: .quota)
    }

    override public init() {
        // Required by Realm
        super.init()
        // primary key is set as default value
    }

    public func categories(for file: File) -> [Category] {
        guard !isInvalidated, !file.isInvalidated else {
            return []
        }

        let fileCategoriesIds: [Int]
        if file.isManagedByRealm {
            fileCategoriesIds = Array(file.categories.sorted(by: \.addedAt, ascending: true)).map(\.categoryId)
        } else {
            fileCategoriesIds = file.categories.sorted { $0.addedAt.compare($1.addedAt) == .orderedAscending }.map(\.categoryId)
        }
        let filteredCategories = categories.filter("id IN %@", fileCategoriesIds)
        return fileCategoriesIds.compactMap { id in filteredCategories.first { $0.id == id } }
    }

    enum CodingKeys: String, CodingKey {
        case accountId
        case id
        case name
        case _pack = "pack"
        case role
        case _preferences = "preferences"
        case size
        case usedSize
        case _users = "users"
        case _teams = "teams"
        case categories
        case _categoryRights = "categoriesPermissions"
        case rights
        case _capabilities = "capabilities"
        case inMaintenance
        case maintenanceReason
        case maintenanceTypes
        case updatedAt
        case _account = "account"
        case accountAdmin
        case isInAppSubscription
        case quota
    }

    public static func == (lhs: Drive, rhs: Drive) -> Bool {
        return lhs.objectId == rhs.objectId
    }
}
