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

public extension DriveInfosManager {
    // MARK: - Get

    func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false, using realm: Realm? = nil) -> [Drive] {
        let realm = realm ?? getRealm()
        realm.refresh()
        var realmDriveList = realm.objects(Drive.self)
            .sorted(byKeyPath: "name", ascending: true)
            .sorted(byKeyPath: "sharedWithMe", ascending: true)
        if let userId {
            let filterPredicate: NSPredicate
            if let sharedWithMe {
                filterPredicate = NSPredicate(format: "userId = %d AND sharedWithMe = %@", userId, NSNumber(value: sharedWithMe))
            } else {
                filterPredicate = NSPredicate(format: "userId = %d", userId)
            }
            realmDriveList = realmDriveList.filter(filterPredicate)
        }
        return Array(realmDriveList.map { $0.freeze() })
    }

    func getFrozenDrive(id: Int, userId: Int) async -> Drive? {
        let realm = getRealm()
        let drive = getFrozenDrive(id: id, userId: userId, using: realm)
        return drive
    }

    func getFrozenDrive(id: Int, userId: Int, using realm: Realm) -> Drive? {
        let objectId = DriveInfosManager.getObjectId(driveId: id, userId: userId)
        return getFrozenDrive(objectId: objectId, using: realm)
    }

    func getFrozenDrive(objectId: String) async -> Drive? {
        let realm = getRealm()
        let drive = getFrozenDrive(objectId: objectId, using: realm)
        return drive
    }

    func getFrozenDrive(objectId: String, using realm: Realm) -> Drive? {
        getLiveDrive(objectId: objectId, using: realm)?.freeze()
    }

    func getLiveDrive(objectId: String, using realm: Realm) -> Drive? {
        guard let drive = realm.object(ofType: Drive.self, forPrimaryKey: objectId),
              !drive.isInvalidated else {
            return nil
        }
        return drive
    }

    func getFrozenUsers(for driveId: Int, userId: Int) async -> [DriveUser] {
        let realm = getRealm()
        let driveUsers = getFrozenUsers(for: driveId, userId: userId, using: realm)
        return driveUsers
    }

    func getFrozenUsers(for driveId: Int, userId: Int, using realm: Realm) -> [DriveUser] {
        guard let drive = getFrozenDrive(id: driveId, userId: userId, using: realm) else {
            return []
        }

        let realmUserList = realm.objects(DriveUser.self).sorted(byKeyPath: "id", ascending: true)
        let users = realmUserList.filter { drive.users.drive.contains($0.id) }
        return users.map { $0.freeze() }
    }

    func getFrozenUser(id: Int) async -> DriveUser? {
        let realm = getRealm()
        let driveUser = getFrozenUser(id: id, using: realm)
        return driveUser
    }

    func getFrozenUser(id: Int, using realm: Realm) -> DriveUser? {
        guard let user = realm.object(ofType: DriveUser.self, forPrimaryKey: id),
              !user.isInvalidated else {
            return nil
        }
        return user.freeze()
    }

    func getFrozenTeams(for driveId: Int, userId: Int) async -> [Team] {
        let realm = getRealm()
        let teams = getFrozenTeams(for: driveId, userId: userId, using: realm)
        return teams
    }

    func getFrozenTeams(for driveId: Int, userId: Int, using realm: Realm) -> [Team] {
        guard let drive = getFrozenDrive(id: driveId, userId: userId, using: realm) else {
            return []
        }

        let realmTeamList = realm.objects(Team.self).sorted(byKeyPath: "id", ascending: true)
        let filteredTeams = realmTeamList.filter { drive.teams.account.contains($0.id) }
        return filteredTeams.map { $0.freeze() }
    }

    func getFrozenTeam(id: Int) async -> Team? {
        let realm = getRealm()
        let team = getFrozenTeam(id: id, using: realm)
        return team
    }

    func getFrozenTeam(id: Int, using realm: Realm) -> Team? {
        guard let team = realm.object(ofType: Team.self, forPrimaryKey: id), !team.isInvalidated else {
            return nil
        }
        return team.freeze()
    }
}
