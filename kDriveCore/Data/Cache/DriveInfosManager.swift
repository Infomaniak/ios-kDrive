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
import FileProvider
import RealmSwift
import InfomaniakCore
import CocoaLumberjackSwift

public class DriveInfosManager {

    public static let instance = DriveInfosManager()
    private let realmConfiguration: Realm.Configuration
    private let dbName = "DrivesInfos.realm"

    private init() {
        realmConfiguration = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent(dbName),
            deleteRealmIfMigrationNeeded: true,
            objectTypes: [Drive.self, DrivePackFunctionality.self, DrivePreferences.self, DriveUsersCategories.self, DriveUser.self, Tag.self])
    }

    private func getRealm() -> Realm {
        return try! Realm(configuration: realmConfiguration)
    }

    private func initDriveForRealm(drive: Drive, userId: Int, sharedWithMe: Bool) {
        drive.userId = userId
        drive.sharedWithMe = sharedWithMe
    }

    private func initFileProviderDomains(drives: [Drive], user: UserProfile) {
        let domainsToAdd = drives.map { NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier($0.objectId), displayName: "\($0.name) (\(user.email))", pathRelativeToDocumentStorage: "\($0.id)") }
        NSFileProviderManager.getDomainsWithCompletionHandler { (allDomains, error) in
            if let error = error {
                DDLogError("Error while getting domains: \(error)")
            }

            let domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(user.id)") }
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { (error) in
                    if let error = error {
                        DDLogError("Error while removing domain \(domain.displayName): \(error)")
                    }
                }
            }
            for domain in domainsToAdd {
                NSFileProviderManager.add(domain) { (error) in
                    if let error = error {
                        DDLogError("Error while adding domain \(domain.displayName): \(error)")
                    }
                }
            }
        }
    }

    func deleteFileProviderDomains(for userId: Int) {
        NSFileProviderManager.getDomainsWithCompletionHandler { (allDomains, error) in
            if let error = error {
                DDLogError("Error while getting domains: \(error)")
            }

            let domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(userId)") }
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { (error) in
                    if let error = error {
                        DDLogError("Error while removing domain \(domain.displayName): \(error)")
                    }
                }
            }
        }
    }

    @discardableResult
    func storeDriveResponse(user: UserProfile, driveResponse: DriveResponse) -> [Drive] {
        var driveList = [Drive]()
        for drive in driveResponse.drives.main {
            initDriveForRealm(drive: drive, userId: user.id, sharedWithMe: false)
            driveList.append(drive)
        }

        for drive in driveResponse.drives.sharedWithMe {
            initDriveForRealm(drive: drive, userId: user.id, sharedWithMe: true)
            driveList.append(drive)
        }

        initFileProviderDomains(drives: driveResponse.drives.main, user: user)

        let driveRemoved = getDrives(for: user.id, sharedWithMe: nil).filter { currentDrive in !driveList.contains(where: { newDrive in newDrive.objectId == currentDrive.objectId }) }
        let driveRemovedIds = driveRemoved.map(\.objectId)
        let realm = getRealm()
        try? realm.write {
            realm.delete(realm.objects(Drive.self).filter("objectId IN %@", driveRemovedIds))
            realm.add(driveList, update: .modified)
            realm.add(driveResponse.users.values, update: .modified)
            realm.add(driveResponse.tags, update: .modified)
        }
        return driveRemoved
    }

    public func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false) -> [Drive] {
        let realm = getRealm()
        var realmDriveList = realm.objects(Drive.self)
            .sorted(byKeyPath: "id", ascending: true)
        if let userId = userId {
            let filterPredicate: NSPredicate
            if let sharedWithMe = sharedWithMe {
                filterPredicate = NSPredicate(format: "userId = %d AND sharedWithMe = %@", userId, NSNumber(booleanLiteral: sharedWithMe))
            } else {
                filterPredicate = NSPredicate(format: "userId = %d", userId)
            }
            realmDriveList = realmDriveList.filter(filterPredicate)
        }
        return Array(realmDriveList.map({ $0.freeze() }))
    }

    public func getDrive(id: Int, userId: Int) -> Drive? {
        return getDrive(objectId: "\(id)_\(userId)")
    }

    public func getDrive(objectId: String) -> Drive? {
        return getRealm().object(ofType: Drive.self, forPrimaryKey: objectId)?.freeze()
    }

    public func getUsers(for driveId: Int) -> [DriveUser] {
        let realm = getRealm()
        let drive = getDrive(id: driveId, userId: AccountManager.instance.currentAccount.userId)
        let realmUserList = realm.objects(DriveUser.self)
            .sorted(byKeyPath: "id", ascending: true)
        var users: [DriveUser] = []
        if let drive = drive {
            for user in realmUserList {
                if drive.users.account.contains(user.id) {
                    users.append(user)
                }
            }
        }
        return users
    }

    public func getUser(id: Int) -> DriveUser? {
        return getRealm().object(ofType: DriveUser.self, forPrimaryKey: id)?.freeze()
    }

    public func getTags() -> [Tag] {
        let realm = getRealm()
        return realm.objects(Tag.self).sorted(byKeyPath: "id", ascending: true).map({ $0 })
    }

    public func getTag(id: Int) -> Tag? {
        let realm = getRealm()
        return realm.object(ofType: Tag.self, forPrimaryKey: id)?.freeze()
    }
}
