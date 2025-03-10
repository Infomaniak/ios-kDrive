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

public extension UploadQueue {
    /// Returns all the UploadFiles currently uploading regardless of execution context
    func getAllUploadingFilesFrozen() -> Results<UploadFile> {
        return uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
            lazyCollection.filter("uploadDate = nil")
                .freezeIfNeeded()
        }
    }

    func getUploadingFiles(withParent parentId: Int,
                           userId: Int,
                           driveId: Int) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        let parentDirectoryPredicate = NSPredicate(format: "parentDirectoryId = %d AND ownedByFileProvider == %@",
                                                   parentId,
                                                   NSNumber(value: ownedByFileProvider))
        return getUploadingFiles(userId: userId, driveId: driveId, optionalPredicate: parentDirectoryPredicate)
    }

    func getUploadingFiles(userId: Int,
                           driveId: Int,
                           optionalPredicate: NSPredicate? = nil) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        return uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
            lazyCollection.filter(
                "uploadDate = nil AND userId = %d AND driveId = %d AND ownedByFileProvider == %@",
                userId,
                driveId,
                NSNumber(value: ownedByFileProvider)
            )
            .filter(optionalPredicate: optionalPredicate)
            .sorted(byKeyPath: "taskCreationDate")
        }
    }

    func getUploadingFiles(userId: Int,
                           driveIds: [Int]) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        return uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
            lazyCollection.filter(
                "uploadDate = nil AND userId = %d AND driveId IN %@ AND ownedByFileProvider == %@",
                userId,
                driveIds,
                NSNumber(value: ownedByFileProvider)
            )
            .sorted(byKeyPath: "taskCreationDate")
        }
    }

    func getUploadedFiles(optionalPredicate: NSPredicate? = nil) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        return uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
            lazyCollection
                .filter("uploadDate != nil AND ownedByFileProvider == %@", NSNumber(value: ownedByFileProvider))
                .filter(optionalPredicate: optionalPredicate)
        }
    }

    func getUploadedFiles(writableRealm: Realm, optionalPredicate: NSPredicate? = nil) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        return writableRealm.objects(UploadFile.self)
            .filter("uploadDate != nil AND ownedByFileProvider == %@", NSNumber(value: ownedByFileProvider))
            .filter(optionalPredicate: optionalPredicate)
    }

    /// Get an UploadFile matching a FileProviderItemIdentifier if any uploading within an execution context
    func getUploadingFile(fileProviderItemIdentifier: String) -> UploadFile? {
        Log.uploadQueue("getUploadingFile: \(fileProviderItemIdentifier)", level: .info)

        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        let matchedFile = uploadsDatabase.fetchObject(ofType: UploadFile.self) { lazyCollection in
            lazyCollection.filter(
                "uploadDate = nil AND fileProviderItemIdentifier = %@ AND ownedByFileProvider == %@",
                fileProviderItemIdentifier,
                NSNumber(value: ownedByFileProvider)
            )
            .first
        }

        return matchedFile
    }

    /// Get an UploadFile matching a FileProviderItemIdentifier if any uploaded within an execution context
    func getUploadedFile(fileProviderItemIdentifier: String) -> UploadFile? {
        Log.uploadQueue("getUploadedFile: \(fileProviderItemIdentifier)", level: .info)

        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        let matchedFile = uploadsDatabase.fetchObject(ofType: UploadFile.self) { lazyCollection in
            lazyCollection.filter(
                "uploadDate != nil AND fileProviderItemIdentifier = %@ AND ownedByFileProvider == %@",
                fileProviderItemIdentifier,
                NSNumber(value: ownedByFileProvider)
            )
            .first
        }

        return matchedFile
    }
}
