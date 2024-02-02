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

import Foundation
import RealmSwift

public extension DriveFileManager {
    // MARK: - Get

    func getCachedRootFile(freeze: Bool = true, using realm: Realm? = nil) -> File {
        if let root = getCachedFile(id: constants.rootID, freeze: false) {
            if root.name != drive.name {
                let realm = realm ?? getRealm()
                realm.refresh()

                try? realm.safeWrite {
                    root.name = drive.name
                }
            }
            return freeze ? root.freeze() : root
        } else {
            return File(id: constants.rootID, name: drive.name)
        }
    }

    func getFrozenAvailableOfflineFiles(sortType: SortType = .nameAZ) -> [File] {
        let offlineFiles = getRealm().objects(File.self)
            .filter(NSPredicate(format: "isAvailableOffline = true"))
            .sorted(by: [sortType.value.sortDescriptor]).freeze()

        return offlineFiles.map { $0.freeze() }
    }

    func getLocalRecentActivities() -> [FileActivity] {
        return Array(getRealm().objects(FileActivity.self).sorted(by: \.createdAt, ascending: false).freeze())
    }

    func getLiveWorkingSet() -> [File] {
        // let predicate = NSPredicate(format: "isFavorite = %d OR lastModifiedAt >= %d", true, Int(Date(timeIntervalSinceNow:
        // -3600).timeIntervalSince1970))
        let files = getRealm().objects(File.self).sorted(by: \.lastModifiedAt, ascending: false)
        var result = [File]()
        for i in 0 ..< min(20, files.count) {
            result.append(files[i])
        }
        return result
    }

    func getFrozenLocalSortedDirectoryFiles(directory: File, sortType: SortType) -> [File] {
        let children = directory.children.sorted(by: [
            SortDescriptor(keyPath: \File.type, ascending: true),
            SortDescriptor(keyPath: \File.visibility, ascending: false),
            sortType.value.sortDescriptor
        ])

        return Array(children.freeze())
    }

    /// Get a live version for the given file (if the file is not cached in realm it is added and then returned)
    /// - Parameters:
    ///   - file: A File to work with
    ///   - realm: Optionally pass a realm
    /// - Returns: A realm managed file
    func getLiveManagedFile(from file: File, using realm: Realm? = nil) -> File {
        let realm = realm ?? getRealm()
        realm.refresh()

        if let cachedFile = getCachedFile(id: file.id, freeze: false, using: realm) {
            return cachedFile
        } else {
            keepCacheAttributesForFile(newFile: file, keepProperties: [.all], using: realm)
            try? realm.write {
                realm.add(file, update: .all)
            }
            return file
        }
    }
}
