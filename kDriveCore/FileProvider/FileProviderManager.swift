//
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

import FileProvider
import Foundation
import InfomaniakCore
import InfomaniakDI
import Realm
import RealmSwift

public class FileProviderManager {
    public let drive: Drive
    public let driveApiFetcher: DriveApiFetcher
    public let realmConfiguration: Realm.Configuration

    public let manager: NSFileProviderManager
    public let domain: NSFileProviderDomain?

    public init?(domain: NSFileProviderDomain?) {
        @InjectService var accountManager: AccountManageable
        guard let token = accountManager.getTokenForUserId(accountManager.currentUserId) else {
            return nil
        }

        if let objectId = domain?.identifier.rawValue,
           let drive = DriveInfosManager.instance.getDrive(objectId: objectId) {
            self.drive = drive
            driveApiFetcher = DriveApiFetcher(token: token, delegate: accountManager)
        } else if let drive = DriveInfosManager.instance.getDrive(id: accountManager.currentDriveId,
                                                                  userId: accountManager.currentUserId) {
            self.drive = drive
            driveApiFetcher = DriveApiFetcher(token: token, delegate: accountManager)
        } else {
            return nil
        }

        self.domain = domain
        if let domain {
            manager = NSFileProviderManager(for: domain) ?? .default
        } else {
            manager = .default
        }

        Log.fileProvider("Starting file provider with realm \(RLMRealmPathForFile(drive.objectId))")
        realmConfiguration = Realm.Configuration(fileURL: URL(
            fileURLWithPath: RLMRealmPathForFile("\(drive.objectId).realm"),
            isDirectory: false
        ))
        initRootIfNeeded()
    }

    func initRootIfNeeded() {
        let root = try? getFile(for: .rootContainer)
        guard root == nil else { return }

        let realm = getRealm()
        try? realm.write {
            let rootFile = File(id: DriveFileManager.constants.rootID, name: drive.name)
            rootFile.driveId = drive.id
            realm.add(rootFile, update: .all)
        }
    }

    public func getRealm() -> Realm {
        do {
            let realm = try Realm(configuration: realmConfiguration)
            realm.refresh()
            return realm
        } catch {
            fatalError("Failed getRealm \(error)")
        }
    }

    public func keepCacheAttributesForFile(newFile: File, using realm: Realm) {
        guard let savedChild = realm.object(ofType: File.self, forPrimaryKey: newFile.id),
              !savedChild.isInvalidated else { return }
        newFile.lastCursor = savedChild.lastCursor
        newFile.responseAt = savedChild.responseAt
        newFile.versionCode = savedChild.versionCode
        newFile.fullyDownloaded = savedChild.fullyDownloaded
        newFile.children = savedChild.children
    }

    public func writeChildrenToParent(
        _ parent: File,
        children: [File],
        shouldClearChildren: Bool,
        using realm: Realm
    ) throws -> [File] {
        assert(!parent.isFrozen, "Parent should be live")
        let realm = getRealm()

        try realm.write {
            if shouldClearChildren {
                parent.children.removeAll()
            }

            for child in children {
                keepCacheAttributesForFile(newFile: child, using: realm)
                realm.add(child, update: .all)
                parent.children.insert(child)
            }
        }

        return children.map { $0.freezeIfNeeded() }
    }

    public func getFile(for identifier: NSFileProviderItemIdentifier,
                        using realm: Realm? = nil,
                        shouldFreeze: Bool = true) throws -> File {
        guard let fileId = identifier.toFileId() else {
            throw NSFileProviderError(.noSuchItem)
        }
        let realm = realm ?? getRealm()

        guard let file = realm.object(ofType: File.self, forPrimaryKey: fileId) else {
            throw NSFileProviderError(.noSuchItem)
        }

        return shouldFreeze ? file.freezeIfNeeded() : file
    }
}
