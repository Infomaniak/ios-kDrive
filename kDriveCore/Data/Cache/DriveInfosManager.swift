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

import CocoaLumberjackSwift
import FileProvider
import Foundation
import InfomaniakCore
import Realm
import RealmSwift
import Sentry

public final class DriveInfosManager: RealmAccessible {
    private static let currentDbVersion: UInt64 = 9
    private let currentFpStorageVersion = 1
    public let realmConfiguration: Realm.Configuration
    private let dbName = "DrivesInfos.realm"
    private var fileProviderManagers: [String: NSFileProviderManager] = [:]

    private class func removeDanglingObjects(ofType type: RLMObjectBase.Type, migration: Migration, ids: Set<String>) {
        migration.enumerateObjects(ofType: type.className()) { oldObject, newObject in
            guard let newObject, let objectId = oldObject?["objectId"] as? String else { return }
            if !ids.contains(objectId) {
                migration.delete(newObject)
            }
        }
    }

    init() {
        realmConfiguration = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent(dbName),
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

    private func initFileProviderDomains(drives: [Drive], user: InfomaniakCore.UserProfile) {
        // Clean file provider storage if needed
        if UserDefaults.shared.fpStorageVersion < currentFpStorageVersion {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: NSFileProviderManager.default.documentStorageURL,
                    includingPropertiesForKeys: nil
                )
                for url in fileURLs {
                    try FileManager.default.removeItem(at: url)
                }
                UserDefaults.shared.fpStorageVersion = currentFpStorageVersion
            } catch {
                // Silently handle error
            }
        }

        let updatedDomains = drives.map {
            NSFileProviderDomain(
                identifier: NSFileProviderDomainIdentifier($0.objectId),
                displayName: "\($0.name) (\(user.email))",
                pathRelativeToDocumentStorage: "\($0.objectId)"
            )
        }
        Task {
            do {
                let allDomains = try await NSFileProviderManager.domains()
                var domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(user.id)") }
                await withThrowingTaskGroup(of: Void.self) { group in
                    for newDomain in updatedDomains {
                        // Check if domain already added
                        if let existingDomainIndex = domainsForCurrentUser
                            .firstIndex(where: { $0.identifier == newDomain.identifier }) {
                            let existingDomain = domainsForCurrentUser.remove(at: existingDomainIndex)
                            // Domain exists but its name could have changed
                            if existingDomain.displayName != newDomain.displayName {
                                group.addTask {
                                    try await NSFileProviderManager.remove(existingDomain)
                                    try await NSFileProviderManager.add(newDomain)
                                }
                            }
                        } else {
                            // Domain didn't exist we have to add it
                            group.addTask {
                                try await NSFileProviderManager.add(newDomain)
                            }
                        }
                    }
                }

                // Remove left domains
                await withThrowingTaskGroup(of: Void.self) { group in
                    for domain in domainsForCurrentUser {
                        group.addTask {
                            try await NSFileProviderManager.remove(domain)
                        }
                    }
                }
            } catch {
                DDLogError("Error while updating file provider domains: \(error)")
            }
        }
    }

    func deleteFileProviderDomains(for userId: Int) {
        NSFileProviderManager.getDomainsWithCompletionHandler { allDomains, error in
            if let error {
                DDLogError("Error while getting domains: \(error)")
            }

            let domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(userId)") }
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { error in
                    if let error {
                        DDLogError("Error while removing domain \(domain.displayName): \(error)")
                    }
                }
            }
        }
    }

    public func deleteAllFileProviderDomains() {
        NSFileProviderManager.removeAllDomains { error in
            if let error {
                DDLogError("Error while removing domains: \(error)")
            }
        }
    }

    func getFileProviderDomain(for driveId: String, completion: @escaping (NSFileProviderDomain?) -> Void) {
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
            if let error {
                DDLogError("Error while getting domains: \(error)")
                completion(nil)
            } else {
                completion(domains.first { $0.identifier.rawValue == driveId })
            }
        }
    }

    public func getFileProviderManager(for drive: Drive, completion: @escaping (NSFileProviderManager) -> Void) {
        getFileProviderManager(for: drive.objectId, completion: completion)
    }

    public func getFileProviderManager(driveId: Int, userId: Int, completion: @escaping (NSFileProviderManager) -> Void) {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)
        getFileProviderManager(for: objectId, completion: completion)
    }

    public func getFileProviderManager(for driveId: String, completion: @escaping (NSFileProviderManager) -> Void) {
        getFileProviderDomain(for: driveId) { domain in
            if let domain {
                completion(NSFileProviderManager(for: domain) ?? .default)
            } else {
                completion(.default)
            }
        }
    }

    @discardableResult
    func storeDriveResponse(user: InfomaniakCore.UserProfile, driveResponse: DriveResponse) -> [Drive] {
        var driveList = [Drive]()
        for drive in driveResponse.drives where drive.role != "none" {
            initDriveForRealm(drive: drive, userId: user.id, sharedWithMe: drive.role == "external")
            driveList.append(drive)
        }

        initFileProviderDomains(drives: driveList.filter { !$0.sharedWithMe }, user: user)

        let realm = getRealm()
        let driveRemoved = getDrives(for: user.id, sharedWithMe: nil, using: realm)
            .filter { currentDrive in !driveList.contains { newDrive in newDrive.objectId == currentDrive.objectId } }
        let driveRemovedIds = driveRemoved.map(\.objectId)
        try? realm.write {
            realm.delete(realm.objects(Drive.self).filter("objectId IN %@", driveRemovedIds))
            realm.add(driveList, update: .modified)
            realm.add(driveResponse.users, update: .modified)
            realm.add(driveResponse.teams, update: .modified)
        }
        return driveRemoved
    }

    public static func getObjectId(driveId: Int, userId: Int) -> String {
        return "\(driveId)_\(userId)"
    }

    public func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false, using realm: Realm? = nil) -> [Drive] {
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

    public func getFrozenDrive(id: Int, userId: Int) async -> Drive? {
        var drive: Drive?
        await realmTransaction.execute { realm in
            drive = self.getFrozenDrive(id: id, userId: userId, using: realm)
        }
        return drive
    }

    public func getFrozenDrive(id: Int, userId: Int, using realm: Realm) -> Drive? {
        let objectId = DriveInfosManager.getObjectId(driveId: id, userId: userId)
        return getFrozenDrive(objectId: objectId, using: realm)
    }

    public func getFrozenDrive(objectId: String) async -> Drive? {
        var drive: Drive?
        await realmTransaction.execute { realm in
            drive = self.getFrozenDrive(objectId: objectId, using: realm)
        }
        return drive
    }

    public func getFrozenDrive(objectId: String, using realm: Realm) -> Drive? {
        getLiveDrive(objectId: objectId, using: realm)?.freeze()
    }

    public func getLiveDrive(objectId: String, using realm: Realm) -> Drive? {
        guard let drive = realm.object(ofType: Drive.self, forPrimaryKey: objectId),
              !drive.isInvalidated else {
            return nil
        }
        return drive
    }

    public func getFrozenUsers(for driveId: Int, userId: Int) async -> [DriveUser] {
        var driveUsers = [DriveUser]()
        await realmTransaction.execute { realm in
            driveUsers = self.getFrozenUsers(for: driveId, userId: userId, using: realm)
        }
        return driveUsers
    }

    public func getFrozenUsers(for driveId: Int, userId: Int, using realm: Realm) -> [DriveUser] {
        guard let drive = getFrozenDrive(id: driveId, userId: userId, using: realm) else {
            return []
        }

        let realmUserList = realm.objects(DriveUser.self).sorted(byKeyPath: "id", ascending: true)
        let users = realmUserList.filter { drive.users.drive.contains($0.id) }
        return users.map { $0.freeze() }
    }

    public func getFrozenUser(id: Int, using realm: Realm) async -> DriveUser? {
        var driveUser: DriveUser?
        await realmTransaction.execute { realm in
            driveUser = self.getFrozenUser(id: id, using: realm)
        }
        return driveUser
    }

    public func getFrozenUser(id: Int, using realm: Realm) -> DriveUser? {
        guard let user = realm.object(ofType: DriveUser.self, forPrimaryKey: id),
              !user.isInvalidated else {
            return nil
        }
        return user.freeze()
    }

    public func getFrozenTeams(for driveId: Int, userId: Int) async -> [Team] {
        var teams = [Team]()
        await realmTransaction.execute { realm in
            teams = self.getFrozenTeams(for: driveId, userId: userId, using: realm)
        }
        return teams
    }

    public func getFrozenTeams(for driveId: Int, userId: Int, using realm: Realm) -> [Team] {
        guard let drive = getFrozenDrive(id: driveId, userId: userId, using: realm) else {
            return []
        }

        let realmTeamList = realm.objects(Team.self).sorted(byKeyPath: "id", ascending: true)
        let filteredTeams = realmTeamList.filter { drive.teams.account.contains($0.id) }
        return filteredTeams.map { $0.freeze() }
    }

    public func getFrozenTeam(id: Int) async -> Team? {
        var team: Team?
        await realmTransaction.execute { realm in
            team = self.getFrozenTeam(id: id, using: realm)
        }
        return team
    }

    public func getFrozenTeam(id: Int, using realm: Realm) -> Team? {
        guard let team = realm.object(ofType: Team.self, forPrimaryKey: id), !team.isInvalidated else {
            return nil
        }
        return team.freeze()
    }
}
