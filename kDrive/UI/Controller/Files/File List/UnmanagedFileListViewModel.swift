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
import Foundation
import kDriveCore
import RealmSwift

class UnmanagedFileListViewModel: FileListViewModel {
    private let realm: Realm

    override init(configuration: Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        if let realm = currentDirectory.realm {
            self.realm = realm
        } else {
            let unCachedRealmConfiguration = Realm.Configuration(inMemoryIdentifier: "uncachedrealm-\(UUID().uuidString)", objectTypes: DriveFileManager.constants.driveObjectTypes)
            do {
                realm = try Realm(configuration: unCachedRealmConfiguration)
            } catch {
                Logging.reportRealmOpeningError(error, realmConfiguration: unCachedRealmConfiguration)
            }
        }

        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        try? realm.write {
            realm.add(currentDirectory)
        }
        files = AnyRealmCollection(AnyRealmCollection(currentDirectory.children).filesSorted(by: sortType))
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        fatalError("init(driveFileManager:currentDirectory:) has not been implemented")
    }

    /// Use this method to add fetched files to the file list. It will replace the list on first page and append the files on following pages.
    /// - Parameters:
    ///   - fetchedFiles: The list of files to add.
    ///   - page: The page of the files.
    final func addPage(files fetchedFiles: [File], page: Int) {
        try? realm.write {
            if page == 1 {
                realm.delete(currentDirectory.children)
            }
            currentDirectory.children.insert(objectsIn: fetchedFiles)
        }
    }

    func removeFiles(_ files: [ProxyFile]) {
        try? realm.write {
            for file in files {
                if let file = realm.object(ofType: File.self, forPrimaryKey: file.id) {
                    realm.delete(file)
                }
            }
        }
    }
}
