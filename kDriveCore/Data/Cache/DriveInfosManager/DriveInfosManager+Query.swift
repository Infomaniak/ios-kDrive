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

    /// Get drive for a given driveId
    func getDrive(id: Int, userId: Int) -> Drive?

    /// Get drive for a given driveId and realm
    func getDrive(id: Int, userId: Int, using realm: Realm) -> Drive?

    /// Get drive for a given primary key
    func getDrive(primaryKey: String, freeze: Bool) -> Drive?

    /// Get drive list for a given primary key and realm
    func getDrive(primaryKey: String, freeze: Bool, using realm: Realm) -> Drive?

    /// Get faulted DriveUser list for a given user id
    func getUsers(for driveId: Int, userId: Int) -> Results<DriveUser>

    /// Get DriveUser for a given primary key
    func getUser(primaryKey: Int) -> DriveUser?

    /// Get DriveUser for a given primary key and realm
    func getTeams(for driveId: Int, userId: Int) -> Results<Team>

    /// Get Team for a given primary key
    func getTeam(primaryKey: Int) -> Team?

    /// Remove all drives linked to a user id
    func removeDrivesFor(userId: Int)
}

public extension DriveInfosManager {
    func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false) -> Results<Drive> {
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

        return driveInfoDatabase.fetchResults(ofType: Drive.self) { lazyCollection in
            lazyCollection
                .filter(optionalPredicate: userIdPredicate)
                .sorted(byKeyPath: "name", ascending: true)
                .sorted(byKeyPath: "sharedWithMe", ascending: true)
        }
    }

    func getDrive(id: Int, userId: Int) -> Drive? {
        let primaryKey = DriveInfosManager.getObjectId(driveId: id, userId: userId)
        return getDrive(primaryKey: primaryKey)
    }

    func getDrive(id: Int, userId: Int, using realm: Realm) -> Drive? {
        let primaryKey = DriveInfosManager.getObjectId(driveId: id, userId: userId)
        return getDrive(primaryKey: primaryKey, using: realm)
    }

    func getDrive(primaryKey: String, freeze: Bool = true) -> Drive? {
        guard let fetchedDrive = driveInfoDatabase.fetchObject(ofType: Drive.self, forPrimaryKey: primaryKey),
              !fetchedDrive.isInvalidated else {
            return nil
        }

        return freeze ? fetchedDrive.freeze() : fetchedDrive
    }

    func getDrive(primaryKey: String, freeze: Bool = true, using realm: Realm) -> Drive? {
        guard let drive = realm.object(ofType: Drive.self, forPrimaryKey: primaryKey), !drive.isInvalidated else {
            return nil
        }
        return freeze ? drive.freeze() : drive
    }

    func getUsers(for driveId: Int, userId: Int) -> Results<DriveUser> {
        guard let drive = getDrive(id: driveId, userId: userId) else {
            return driveInfoDatabase.fetchResults(ofType: DriveUser.self) { lazyCollection in
                lazyCollection.sorted(byKeyPath: "id", ascending: true)
            }
        }

        return driveInfoDatabase.fetchResults(ofType: DriveUser.self) { lazyCollection in
            let users = Array(drive.users.drive)
            return lazyCollection
                .sorted(byKeyPath: "id", ascending: true)
                .filter("id IN %@", users)
        }
    }

    func getUser(primaryKey: Int) -> DriveUser? {
        guard let user = driveInfoDatabase.fetchObject(ofType: DriveUser.self, forPrimaryKey: primaryKey),
              !user.isInvalidated else {
            return nil
        }
        return user.freeze()
    }

    func getTeams(for driveId: Int, userId: Int) -> Results<Team> {
        guard let drive = getDrive(id: driveId, userId: userId) else {
            return driveInfoDatabase.fetchResults(ofType: Team.self) { lazyCollection in
                lazyCollection.sorted(byKeyPath: "id", ascending: true)
            }
        }

        return driveInfoDatabase.fetchResults(ofType: Team.self) { lazyCollection in
            let teamAccounts = Array(drive.teams.account)
            return lazyCollection
                .sorted(byKeyPath: "id", ascending: true)
                .filter("id IN %@", teamAccounts)
        }
    }

    func getTeam(primaryKey: Int) -> Team? {
        guard let team = driveInfoDatabase.fetchObject(ofType: Team.self, forPrimaryKey: primaryKey),
              !team.isInvalidated else {
            return nil
        }

        return team
    }

    private func getTeam(primaryKey: Int, using realm: Realm) -> Team? {
        guard let team = realm.object(ofType: Team.self, forPrimaryKey: primaryKey),
              !team.isInvalidated else {
            return nil
        }
        return team.freeze()
    }

    func removeDrivesFor(userId: Int) {
        try? driveInfoDatabase.writeTransaction { writableRealm in
            let userDrives = writableRealm.objects(Drive.self).where { $0.userId == userId }
            writableRealm.delete(userDrives)
        }
    }
}
