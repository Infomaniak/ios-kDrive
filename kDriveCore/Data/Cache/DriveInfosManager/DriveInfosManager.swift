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
import InfomaniakCoreDB
import InfomaniakDI
import Realm
import RealmSwift
import Sentry

// TODO: Move to core db / + tests
public extension Results where Element: KeypathSortable {
    /// Apply a filter only for non nil predicate parameters, noop otherwise
    func filter(optionalPredicate predicate: NSPredicate?) -> Results<Element> {
        guard let predicate else {
            return self
        }

        return filter(predicate)
    }

    /// Apply a collection of filters
    func filter(optionalPredicates predicates: [NSPredicate]) -> Results<Element> {
        var predicates = predicates
        guard let predicate = predicates.popLast() else {
            return self
        }

        let lazyCollection = filter(predicate)
        let result = lazyCollection.filter(optionalPredicates: predicates)
        return result
    }
}

public final class DriveInfosManager: DriveInfosManagerQueryable {
    private static let dbName = "DrivesInfos.realm"

    private static let currentDbVersion: UInt64 = 11

    let currentFpStorageVersion = 1

    public static let realmConfiguration = Realm.Configuration(
        fileURL: DriveFileManager.constants.realmRootURL.appendingPathComponent(dbName),
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

    private class func removeDanglingObjects(ofType type: RLMObjectBase.Type, migration: Migration, ids: Set<String>) {
        migration.enumerateObjects(ofType: type.className()) { oldObject, newObject in
            guard let newObject, let objectId = oldObject?["objectId"] as? String else { return }
            if !ids.contains(objectId) {
                migration.delete(newObject)
            }
        }
    }

    /// Fetch and write into DB with this object
    @LazyInjectService(customTypeIdentifier: kDriveDBID.driveInfo) var driveInfoDatabase: Transactionable

    init() {
        // META: Keep SonarCloud happy
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

        let driveRemoved = getDrives(for: user.id, sharedWithMe: nil)
            .filter { currentDrive in
                !driveList.contains { newDrive in
                    newDrive.objectId == currentDrive.objectId
                }
            }
        let driveRemovedIds = Array(driveRemoved.map(\.objectId))

        try? driveInfoDatabase.writeTransaction { writableRealm in
            let drivesToDelete = writableRealm.objects(Drive.self).filter("objectId IN %@", driveRemovedIds)
            writableRealm.delete(drivesToDelete)
            writableRealm.add(driveList, update: .modified)
            writableRealm.add(driveResponse.users, update: .modified)
            writableRealm.add(driveResponse.teams, update: .modified)
        }

        // driveList is _live_ after the write operation
        updateFileProvider(withLiveDrives: driveList, user: user)

        return Array(driveRemoved)
    }

    private func updateFileProvider(withLiveDrives liveDrives: [Drive], user: InfomaniakUser) {
        let frozenNotSharedWithMe = liveDrives.map { $0.freeze() }
        updateFileProvider(withFrozenDrives: frozenNotSharedWithMe, user: user)
    }

    private func updateFileProvider(withFrozenDrives frozenDrives: [Drive], user: InfomaniakUser) {
        let frozenNotSharedWithMe = frozenDrives
            .filter { !$0.sharedWithMe }
        initFileProviderDomains(frozenDrives: frozenNotSharedWithMe, user: user)
    }

    public static func getObjectId(driveId: Int, userId: Int) -> String {
        return "\(driveId)_\(userId)"
    }
}
