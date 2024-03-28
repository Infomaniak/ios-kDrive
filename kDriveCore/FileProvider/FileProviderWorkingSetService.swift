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

import CoreServices
import FileProvider
import Foundation
import InfomaniakDI

/// Something to access and mutate the WorkingSet
public protocol FileProviderWorkingSetServiceable {
    /// Get a File within the WorkingSet from indentifier
    func getWorkingDocument(forKey key: NSFileProviderItemIdentifier) -> NSFileProviderItem?

    /// Get all the files within the WorkingSet
    func getWorkingDocumentValues() -> [NSFileProviderItem]

    /// Set a File in the WorkingSet DB
    func setWorkingDocument(detachedFile: File)

    /// Remove a File from the WorkingSet, given a `NSFileProviderItemIdentifier`
    func removeWorkingDocument(forKey key: NSFileProviderItemIdentifier)

    /// Remove a File from the WorkingSet, given a `fileId`
    func removeWorkingDocument(forFileId fileId: Int)
}

public final class FileProviderWorkingSetService: FileProviderWorkingSetServiceable {
    /// Internal drive file manager
    let workingSetDriveFileManager: DriveFileManager

    init?(driveId: Int, userId: Int) {
        @InjectService var accountManager: AccountManageable
        guard let workingSetFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId)?
            .instanceWith(context: .fileProviderWorkingSet) else {
            Log.fileProvider("FileProviderWorkingSetService unable to init", level: .error)
            return nil
        }

        workingSetDriveFileManager = workingSetFileManager
    }

    public func getWorkingDocument(forKey key: NSFileProviderItemIdentifier) -> NSFileProviderItem? {
        Log.fileProvider("getWorkingDocument key:\(key.rawValue)")
        guard let fileId = key.toFileId() else {
            Log.fileProvider("getWorkingDocument unable to get fileId for key:\(key.rawValue)", level: .error)
            return nil
        }

        let realm = workingSetDriveFileManager.getRealm()
        guard let file = realm.objects(File.self)
            .filter("id == %@", NSNumber(value: fileId))
            .first(where: \.isDownloaded) /* File must exist locally for WorkingSet (apple doc) */ else {
            return nil
        }

        let fileProviderItem = FileProviderItem(file: file, domain: nil)
        return fileProviderItem
    }

    public func getWorkingDocumentValues() -> [NSFileProviderItem] {
        Log.fileProvider("getWorkingDocumentValues")

        let realm = workingSetDriveFileManager.getRealm()

        // File must exist locally for WorkingSet (apple doc), so we check on File System
        let realmFiles = Array(realm.objects(File.self).filter(\.isDownloaded))

        let files = realmFiles.map { file in
            autoreleasepool {
                return file.toFileProviderItem()
            }
        }

        Log.fileProvider("getWorkingDocument count:\(files.count)")

        return files
    }

    public func setWorkingDocument(detachedFile: File) {
        Log.fileProvider("setWorkingDocument fid:\(detachedFile.id)")
        assert(detachedFile.realm == nil, "expecting a file not linked to a realm to be able to add it")

        do {
            try workingSetDriveFileManager.transaction { realm in
                realm.add(detachedFile, update: .modified)
            }
        } catch {
            Log.fileProvider("setWorkingDocument transaction error: \(error)", level: .error)
        }
    }

    public func removeWorkingDocument(forKey key: NSFileProviderItemIdentifier) {
        Log.fileProvider("removeWorkingDocument key:\(key.rawValue)")

        guard let fileId = key.toFileId() else {
            Log.fileProvider("removeWorkingDocument unable to get fileId for key:\(key.rawValue)", level: .error)
            return
        }

        removeWorkingDocument(forFileId: fileId)
    }

    public func removeWorkingDocument(forFileId fileId: Int) {
        do {
            try workingSetDriveFileManager.transaction { realm in
                guard let fileToRemove = realm.objects(File.self)
                    .filter("id == %@", NSNumber(value: fileId))
                    .first(where: \.isDownloaded) /* File must exist locally for WorkingSet (apple doc) */ else {
                    return
                }

                realm.delete(fileToRemove)
            }
        } catch {
            Log.fileProvider("removeWorkingDocument transaction error: \(error)", level: .error)
        }
    }
}
