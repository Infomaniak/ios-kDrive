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
import RealmSwift

public protocol UploadServiceDataSourceable {
    func getUploadingFile(fileProviderItemIdentifier: String) -> UploadFile?

    func getUploadedFile(fileProviderItemIdentifier: String) -> UploadFile?

    func getUploadingFiles(withParent parentId: Int,
                           userId: Int,
                           driveId: Int) -> Results<UploadFile>

    func getUploadingFiles(userId: Int,
                           driveIds: [Int]) -> Results<UploadFile>

    func getAllUploadingFilesFrozen() -> Results<UploadFile>

    func getUploadedFiles(optionalPredicate: NSPredicate?) -> Results<UploadFile>

    func getUploadedFiles(writableRealm: Realm, optionalPredicate: NSPredicate?) -> Results<UploadFile>

    @discardableResult
    func saveToRealm(_ uploadFile: UploadFile,
                     itemIdentifier: NSFileProviderItemIdentifier?,
                     addToQueue: Bool) -> UploadOperationable?
}

extension UploadService: UploadServiceDataSourceable {
    public func getUploadingFile(fileProviderItemIdentifier: String) -> UploadFile? {
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

    public func getUploadedFile(fileProviderItemIdentifier: String) -> UploadFile? {
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

    public func getUploadingFiles(withParent parentId: Int,
                                  userId: Int,
                                  driveId: Int) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        let parentDirectoryPredicate = NSPredicate(format: "parentDirectoryId = %d AND ownedByFileProvider == %@",
                                                   parentId,
                                                   NSNumber(value: ownedByFileProvider))
        return getUploadingFiles(userId: userId, driveId: driveId, optionalPredicate: parentDirectoryPredicate)
    }

    public func getUploadingFiles(userId: Int,
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

    public func getAllUploadingFilesFrozen() -> Results<UploadFile> {
        return uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
            lazyCollection.filter("uploadDate = nil")
                .freezeIfNeeded()
        }
    }

    public func getUploadedFiles(optionalPredicate: NSPredicate? = nil) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        return uploadsDatabase.fetchResults(ofType: UploadFile.self) { lazyCollection in
            lazyCollection
                .filter("uploadDate != nil AND ownedByFileProvider == %@", NSNumber(value: ownedByFileProvider))
                .filter(optionalPredicate: optionalPredicate)
        }
    }

    public func getUploadedFiles(writableRealm: Realm, optionalPredicate: NSPredicate? = nil) -> Results<UploadFile> {
        let ownedByFileProvider = appContextService.context == .fileProviderExtension
        return writableRealm.objects(UploadFile.self)
            .filter("uploadDate != nil AND ownedByFileProvider == %@", NSNumber(value: ownedByFileProvider))
            .filter(optionalPredicate: optionalPredicate)
    }

    @discardableResult
    public func saveToRealm(_ uploadFile: UploadFile,
                            itemIdentifier: NSFileProviderItemIdentifier? = nil,
                            addToQueue: Bool = true) -> UploadOperationable? {
        let expiringActivity = ExpiringActivity()
        expiringActivity.start()
        defer {
            expiringActivity.endAll()
        }

        Log.uploadQueue("saveToRealm addToQueue:\(addToQueue) ufid:\(uploadFile.id)")

        assert(!uploadFile.isManagedByRealm, "we expect the file to be outside of realm at the moment")

        // Save drive and directory
        UserDefaults.shared.lastSelectedUser = uploadFile.userId
        UserDefaults.shared.lastSelectedDrive = uploadFile.driveId
        UserDefaults.shared.lastSelectedDirectory = uploadFile.parentDirectoryId

        uploadFile.name = uploadFile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if uploadFile.error != nil {
            uploadFile.error = nil
        }

        let detachedFile = uploadFile.detached()
        try? uploadsDatabase.writeTransaction { writableRealm in
            Log.uploadQueue("save ufid:\(uploadFile.id)")
            writableRealm.add(uploadFile, update: .modified)
            Log.uploadQueue("did save ufid:\(uploadFile.id)")
        }

        guard addToQueue else {
            return nil
        }

        guard appContextService.context != .shareExtension else {
            Log.uploadQueue("addToQueue disabled in ShareExtension", level: .error)
            return nil
        }

        let uploadOperation = globalUploadQueue.addToQueue(uploadFile: detachedFile, itemIdentifier: itemIdentifier)
        return uploadOperation
    }
}

extension UploadService {
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
}
