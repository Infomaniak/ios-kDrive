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

///  DriveInfosManager database API
public protocol DriveInfosManagerQueryable {
    /// Get faulted drive list for a given user id
    func getDrives(for userId: Int?, sharedWithMe: Bool?) -> Results<Drive>

    /// Get faulted drive list for a given user id and realm
    func getDrives(for userId: Int?, sharedWithMe: Bool?, using realm: Realm) -> Results<Drive>

    /// Get drive for a given driveId
    func getDrive(id: Int, userId: Int) -> Drive?

    /// Get drive for a given driveId and realm
    func getDrive(id: Int, userId: Int, using realm: Realm) -> Drive?

    /// Get drive for a given primary key
    func getDrive(objectId: String, freeze: Bool) -> Drive?

    /// Get drive list for a given primary key and realm
    func getDrive(objectId: String, freeze: Bool, using realm: Realm) -> Drive?

    /// Get faulted DriveUser list for a given user id
    func getUsers(for driveId: Int, userId: Int) -> Results<DriveUser>

    /// Get DriveUser for a given primary key
    func getUser(id: Int) -> DriveUser?

    /// Get DriveUser for a given primary key and realm
    func getTeams(for driveId: Int, userId: Int) -> Results<Team>

    /// Get Team for a given primary key
    func getTeam(id: Int) -> Team?

    /// Remove all drives linked to a user id
    func removeDrivesFor(userId: Int)
}

public extension DriveInfosManager {
    func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false) -> Results<Drive> {
        return fetchResults(ofType: Drive.self) { realm in
            getDrives(for: userId, sharedWithMe: sharedWithMe, using: realm)
        }
    }

    func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false, using realm: Realm) -> Results<Drive> {
        let userIdPredicate: NSPredicate?
        if let userId {
            if let sharedWithMe {
                userIdPredicate = NSPredicate(format: "userId = %d AND sharedWithMe = %@", userId, NSNumber(value: sharedWithMe))
            } else {
                userIdPredicate = NSPredicate(format: "userId = %d", userId)
            }
        } else {
            userIdPredicate = nil
        }

        let realmDriveList = realm.objects(Drive.self)
            .filter(optionalPredicate: userIdPredicate)
            .sorted(byKeyPath: "name", ascending: true)
            .sorted(byKeyPath: "sharedWithMe", ascending: true)

        return realmDriveList
    }

    func getDrive(id: Int, userId: Int) -> Drive? {
        return try? fetchObject(ofType: Drive.self) { realm in
            getDrive(id: id, userId: userId, using: realm)
        }
    }

    func getDrive(id: Int, userId: Int, using realm: Realm) -> Drive? {
        return getDrive(objectId: DriveInfosManager.getObjectId(driveId: id, userId: userId), using: realm)
    }

    func getDrive(objectId: String, freeze: Bool = true) -> Drive? {
        return try? fetchObject(ofType: Drive.self) { realm in
            return getDrive(objectId: objectId, freeze: freeze, using: realm)
        }
    }

    func getDrive(objectId: String, freeze: Bool = true, using realm: Realm) -> Drive? {
        guard let drive = realm.object(ofType: Drive.self, forPrimaryKey: objectId), !drive.isInvalidated else {
            return nil
        }
        return freeze ? drive.freeze() : drive
    }

    func getUsers(for driveId: Int, userId: Int) -> Results<DriveUser> {
        return fetchResults(ofType: DriveUser.self) { realm in
            getUsers(for: driveId, userId: userId, using: realm)
        }
    }

    private func getUsers(for driveId: Int, userId: Int, using realm: Realm) -> Results<DriveUser> {
        guard let drive = getDrive(id: driveId, userId: userId, using: realm) else {
            return realm.objects(DriveUser.self).sorted(byKeyPath: "id", ascending: true)
        }

        let users = Array(drive.users.drive)
        let realmUserList = realm.objects(DriveUser.self)
            .sorted(byKeyPath: "id", ascending: true)
            .filter("id IN %@", users)

        return realmUserList
    }

    func getUser(id: Int) -> DriveUser? {
        return try? fetchObject(ofType: DriveUser.self) { realm in
            getUser(id: id, using: realm)
        }
    }

    private func getUser(id: Int, using realm: Realm) -> DriveUser? {
        guard let user = realm.object(ofType: DriveUser.self, forPrimaryKey: id),
              !user.isInvalidated else {
            return nil
        }
        return user.freeze()
    }

    func getTeams(for driveId: Int, userId: Int) -> Results<Team> {
        return fetchResults(ofType: Team.self) { realm in
            getTeams(for: driveId, userId: userId, using: realm)
        }
    }

    private func getTeams(for driveId: Int, userId: Int, using realm: Realm) -> Results<Team> {
        guard let drive = getDrive(id: driveId, userId: userId, using: realm) else {
            return realm.objects(Team.self).sorted(byKeyPath: "id", ascending: true)
        }

        let teamAccounts = Array(drive.teams.account)
        let realmTeamList = realm.objects(Team.self)
            .sorted(byKeyPath: "id", ascending: true)
            .filter("id IN %@", teamAccounts)

        return realmTeamList
    }

    func getTeam(id: Int) -> Team? {
        return try? fetchObject(ofType: Team.self) { realm in
            getTeam(id: id, using: realm)
        }
    }

    private func getTeam(id: Int, using realm: Realm) -> Team? {
        guard let team = realm.object(ofType: Team.self, forPrimaryKey: id), !team.isInvalidated else {
            return nil
        }
        return team.freeze()
    }

    func removeDrivesFor(userId: Int) {
        try? writeTransaction { writableRealm in
            let userDrives = writableRealm.objects(Drive.self).where { $0.userId == userId }
            writableRealm.delete(userDrives)
        }
    }
}
