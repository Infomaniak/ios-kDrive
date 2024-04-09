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
import Realm
import RealmSwift
import Sentry

// TODO: Move to core db / + tests
public extension RealmCollection where Element: KeypathSortable {
    /// Apply a filter only for non nil predicate parameters, noop otherwise
    func filter(optionalPredicate predicate: NSPredicate?) -> Results<Element> {
        guard let predicate else {
            return filter("")
        }

        return filter(predicate)
    }
}

public final class DriveInfosManager {
    private static let dbName = "DrivesInfos.realm"

    private static let currentDbVersion: UInt64 = 11

    let currentFpStorageVersion = 1

    public let realmConfiguration: Realm.Configuration

    // TODO: use DI
    public static let instance = DriveInfosManager()

    private class func removeDanglingObjects(ofType type: RLMObjectBase.Type, migration: Migration, ids: Set<String>) {
        migration.enumerateObjects(ofType: type.className()) { oldObject, newObject in
            guard let newObject, let objectId = oldObject?["objectId"] as? String else { return }
            if !ids.contains(objectId) {
                migration.delete(newObject)
            }
        }
    }

    private init() {
        realmConfiguration = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent(Self.dbName),
            schemaVersion: DriveInfosManager.currentDbVersion,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < DriveInfosManager.currentDbVersion {
                    // No migration needed from 0 to 1 & from 2 to 3
                    if oldSchemaVersion < 2 {
                        // Remove tags
                        migration.deleteData(forType: Tag.className())
                    }
                    // No migration needed for versions 3 & 4
                    if oldSchemaVersion < 5 {
                        // Get drive ids
                        var driveIds = Set<String>()
                        migration.enumerateObjects(ofType: Drive.className()) { oldObject, _ in
                            if let objectId = oldObject?["objectId"] as? String {
                                driveIds.insert(objectId)
                            }
                        }
                        // Remove dangling objects
                        DriveInfosManager.removeDanglingObjects(
                            ofType: DrivePreferences.self,
                            migration: migration,
                            ids: driveIds
                        )
                        DriveInfosManager.removeDanglingObjects(
                            ofType: DriveUsersCategories.self,
                            migration: migration,
                            ids: driveIds
                        )
                        DriveInfosManager.removeDanglingObjects(
                            ofType: DriveTeamsCategories.self,
                            migration: migration,
                            ids: driveIds
                        )
                        DriveInfosManager.removeDanglingObjects(ofType: Category.self, migration: migration, ids: driveIds)
                        // Delete team details & category rights for migration
                        migration.deleteData(forType: CategoryRights.className())
                    }
                }
            },
            objectTypes: [
                Drive.self,
                DrivePreferences.self,
                DriveUsersCategories.self,
                DriveTeamsCategories.self,
                DriveUser.self,
                DrivePack.self,
                DriveCapabilities.self,
                DrivePackCapabilities.self,
                DriveRights.self,
                DriveAccount.self,
                Team.self,
                Category.self,
                CategoryRights.self
            ]
        )
    }

    private func initDriveForRealm(drive: Drive, userId: Int, sharedWithMe: Bool) {
        drive.userId = userId
        drive.sharedWithMe = sharedWithMe
    }

    @discardableResult
    func storeDriveResponse(user: InfomaniakCore.UserProfile, driveResponse: DriveResponse) -> [Drive] {
        var driveList = [Drive]()
        for drive in driveResponse.drives where drive.role != "none" {
            initDriveForRealm(drive: drive, userId: user.id, sharedWithMe: drive.role == "external")
            driveList.append(drive)
        }

        var driveRemoved = [Drive]()
        try? writeTransaction { writableRealm in
            driveRemoved = getDrives(for: user.id, sharedWithMe: nil, using: writableRealm)
                .filter { currentDrive in
                    !driveList.contains { newDrive in
                        newDrive.objectId == currentDrive.objectId
                    }
                }
            let driveRemovedIds = driveRemoved.map(\.objectId)

            let drivesToDelete = writableRealm.objects(Drive.self).filter("objectId IN %@", driveRemovedIds)
            writableRealm.delete(drivesToDelete)
            writableRealm.add(driveList, update: .modified)
            writableRealm.add(driveResponse.users, update: .modified)
            writableRealm.add(driveResponse.teams, update: .modified)
        }

        // driveList is _live_ after the write operation
        updateFileProvider(withLiveDrives: driveList, user: user)

        return driveRemoved
    }

    private func updateFileProvider(withLiveDrives liveDrives: [Drive], user: InfomaniakCore.UserProfile) {
        let frozenNotSharedWithMe = liveDrives
            .filter { !$0.sharedWithMe }
            .map { $0.freeze() }
        initFileProviderDomains(frozenDrives: frozenNotSharedWithMe, user: user)
    }

    public static func getObjectId(driveId: Int, userId: Int) -> String {
        return "\(driveId)_\(userId)"
    }

    public func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false) -> Results<Drive> {
        return fetchResults(ofType: Drive.self) { realm in
            getDrives(for: userId, sharedWithMe: sharedWithMe, using: realm)
        }
    }

    private func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false, using realm: Realm) -> Results<Drive> {
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

    public func getDrive(id: Int, userId: Int) -> Drive? {
        return try? fetchObject(ofType: Drive.self) { realm in
            getDrive(id: id, userId: userId, using: realm)
        }
    }

    public func getDrive(id: Int, userId: Int, using realm: Realm) -> Drive? {
        return getDrive(objectId: DriveInfosManager.getObjectId(driveId: id, userId: userId), using: realm)
    }

    public func getDrive(objectId: String, freeze: Bool = true) -> Drive? {
        return try? fetchObject(ofType: Drive.self) { realm in
            return getDrive(objectId: objectId, freeze: freeze, using: realm)
        }
    }

    public func getDrive(objectId: String, freeze: Bool = true, using realm: Realm) -> Drive? {
        guard let drive = realm.object(ofType: Drive.self, forPrimaryKey: objectId), !drive.isInvalidated else {
            return nil
        }
        return freeze ? drive.freeze() : drive
    }

    public func getUsers(for driveId: Int, userId: Int) -> Results<DriveUser> {
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

    public func getUser(id: Int) -> DriveUser? {
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

    public func getTeams(for driveId: Int, userId: Int) -> Results<Team> {
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

    public func getTeam(id: Int) -> Team? {
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

    public func removeDrivesFor(userId: Int) {
        try? writeTransaction { writableRealm in
            let userDrives = writableRealm.objects(Drive.self).where { $0.userId == userId }
            writableRealm.delete(userDrives)
        }
    }
}
