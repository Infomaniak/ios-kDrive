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

public class DriveInfosManager {
    public static let instance = DriveInfosManager()
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

    private init() {
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

    public func getRealm() -> Realm {
        do {
            return try Realm(configuration: realmConfiguration)
        } catch {
            // We can't recover from this error but at least we report it correctly on Sentry
            Logging.reportRealmOpeningError(error, realmConfiguration: realmConfiguration)
        }
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

    public func getDrive(id: Int, userId: Int, using realm: Realm? = nil) -> Drive? {
        return getDrive(objectId: DriveInfosManager.getObjectId(driveId: id, userId: userId), using: realm)
    }

    public func getDrive(objectId: String, freeze: Bool = true, using realm: Realm? = nil) -> Drive? {
        let realm = realm ?? getRealm()
        guard let drive = realm.object(ofType: Drive.self, forPrimaryKey: objectId), !drive.isInvalidated else {
            return nil
        }
        return freeze ? drive.freeze() : drive
    }

    public func getUsers(for driveId: Int, userId: Int, using realm: Realm? = nil) -> [DriveUser] {
        let realm = realm ?? getRealm()
        let drive = getDrive(id: driveId, userId: userId, using: realm)
        let realmUserList = realm.objects(DriveUser.self).sorted(byKeyPath: "id", ascending: true)
        if let drive {
            return realmUserList.filter { drive.users.drive.contains($0.id) }
        }
        return []
    }

    public func getUser(id: Int, using realm: Realm? = nil) -> DriveUser? {
        let realm = realm ?? getRealm()
        guard let user = realm.object(ofType: DriveUser.self, forPrimaryKey: id), !user.isInvalidated else {
            return nil
        }
        return user.freeze()
    }

    public func getTeams(for driveId: Int, userId: Int, using realm: Realm? = nil) -> [Team] {
        let realm = realm ?? getRealm()
        let drive = getDrive(id: driveId, userId: userId, using: realm)
        let realmTeamList = realm.objects(Team.self).sorted(byKeyPath: "id", ascending: true)
        if let drive {
            return realmTeamList.filter { drive.teams.account.contains($0.id) }
        }
        return []
    }

    public func getTeam(id: Int, using realm: Realm? = nil) -> Team? {
        let realm = realm ?? getRealm()
        guard let team = realm.object(ofType: Team.self, forPrimaryKey: id), !team.isInvalidated else {
            return nil
        }
        return team.freeze()
    }
}
