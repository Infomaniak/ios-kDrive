/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

public extension DriveFileManager {
    func getCachedRootFile(freeze: Bool = true) -> File {
        var file: File!
        try? writeTransaction { writableRealm in
            file = getCachedRootFile(freeze: freeze, writableRealm: writableRealm)
        }
        return file
    }

    func getCachedRootFile(freeze: Bool = true, writableRealm: Realm) -> File {
        if let root = getCachedFile(id: DriveFileManager.constants.rootID, freeze: false, using: writableRealm) {
            if root.name != drive.name {
                root.name = drive.name
            }
            return freeze ? root.freeze() : root
        } else {
            return File(id: DriveFileManager.constants.rootID, name: drive.name, driveId: drive.id)
        }
    }

    func getCachedMyFilesRoot() -> File? {
        let file = try? fetchObject(ofType: File.self) { faultedCollection in
            faultedCollection.filter("rawVisibility == %@", FileVisibility.isPrivateSpace.rawValue)
                .first?
                .freeze()
        }

        guard let file, !file.isInvalidated else {
            return nil
        }

        return file
    }

    func getCachedFile(id: Int, freeze: Bool = true) -> File? {
        let uid = File.uid(driveId: drive.id, fileId: id)
        guard let file = fetchObject(ofType: File.self, forPrimaryKey: uid), !file.isInvalidated else {
            return nil
        }
        return freeze ? file.freeze() : file
    }

    func getCachedFile(id: Int, freeze: Bool = true, using realm: Realm) -> File? {
        let uid = File.uid(driveId: drive.id, fileId: id)
        guard let file = realm.object(ofType: File.self, forPrimaryKey: uid), !file.isInvalidated else {
            return nil
        }
        return freeze ? file.freeze() : file
    }

    func getLocalRecentActivities() -> [FileActivity] {
        let frozenFileActivities = fetchResults(ofType: FileActivity.self) { faultedCollection in
            faultedCollection.sorted(by: \.createdAt, ascending: false).freeze()
        }
        return Array(frozenFileActivities)
    }

    func getWorkingSet() -> [File] {
        // let predicate = NSPredicate(format: "isFavorite = %d OR lastModifiedAt >= %d", true, Int(Date(timeIntervalSinceNow:
        // -3600).timeIntervalSince1970))
        let files = fetchResults(ofType: File.self) { faultedCollection in
            faultedCollection.sorted(by: \.lastModifiedAt, ascending: false)
        }

        var result = [File]()
        for i in 0 ..< min(20, files.count) {
            result.append(files[i])
        }
        return result
    }

    /// Get a live version for the given file (if the file is not cached in realm it is added and then returned)
    /// - Parameters:
    ///   - file: source file
    /// - Returns: A realm managed file
    func getManagedFile(from file: File) -> File {
        // TODO: Refactor
        var fetchedFile: File!
        try? writeTransaction { writableRealm in
            fetchedFile = getManagedFile(from: file, writableRealm: writableRealm)
        }
        return fetchedFile
    }

    /// Get a live version for the given file (if the file is not cached in realm it is added and then returned)
    /// - Parameters:
    ///   - file: source file
    ///   - writableRealm: A realm _within_ a write operation
    /// - Returns: A realm managed file
    func getManagedFile(from file: File, writableRealm: Realm) -> File {
        if let cachedFile = getCachedFile(id: file.id, freeze: false, using: writableRealm) {
            return cachedFile
        } else {
            if file.isRoot {
                file.driveId = drive.id
                file.uid = File.uid(driveId: file.driveId, fileId: file.id)
            }

            keepCacheAttributesForFile(newFile: file, keepProperties: [.all], writableRealm: writableRealm)

            writableRealm.add(file, update: .all)
            return file
        }
    }
}
