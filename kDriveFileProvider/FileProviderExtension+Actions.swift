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

import FileProvider
import kDriveCore

extension FileProviderExtension {
    override func createDirectory(
        withName directoryName: String,
        inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        Log.fileProvider("createDirectory withName '\(directoryName)'")
        Task {
            guard let fileId = parentItemIdentifier.toFileId(),
                  let file = self.driveFileManager.getCachedFile(id: fileId) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            // Call completion handler with error if the file name already exists
            let itemsWithSameParent = file.children
                .map { FileProviderItem(file: $0, domain: self.domain) } + self.fileProviderState
                .importedDocuments(forParent: parentItemIdentifier)
            let newItemFileName = directoryName.lowercased()
            if let collidingItem = itemsWithSameParent.first(where: { $0.filename.lowercased() == newItemFileName }),
               !collidingItem.isTrashed {
                completionHandler(nil, NSError.fileProviderErrorForCollision(with: collidingItem))
                return
            }

            let proxyFile = file.proxify()
            do {
                let directory = try await self.driveFileManager.createDirectory(
                    in: proxyFile,
                    name: directoryName,
                    onlyForMe: false
                )
                completionHandler(FileProviderItem(file: directory, domain: self.domain), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func deleteItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Log.fileProvider("deleteItem")
        Task {
            guard let fileId = itemIdentifier.toFileId() else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }

            do {
                let response = try await self.driveFileManager.apiFetcher
                    .deleteDefinitely(file: ProxyFile(driveId: self.driveFileManager.drive.id, id: fileId))
                if response {
                    self.fileProviderState.removeWorkingDocument(forKey: itemIdentifier)
                    completionHandler(nil)

                    // Signal after completionHandler
                    try await self.manager.signalEnumerator(for: .workingSet)
                    try await self.manager.signalEnumerator(for: itemIdentifier)
                } else {
                    completionHandler(NSFileProviderError(.serverUnreachable))
                }
            } catch {
                completionHandler(error)
            }
        }
    }

    override func importDocument(
        at fileURL: URL,
        toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        Log.fileProvider("importDocument")
        let accessingSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()

        // Call completion handler with error if the file name already exists
        guard let fileId = parentItemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let itemsWithSameParent = file.children
            .map { FileProviderItem(file: $0, domain: self.domain) } + fileProviderState
            .importedDocuments(forParent: parentItemIdentifier)
        let newItemFileName = fileURL.lastPathComponent.lowercased()
        if let collidingItem = itemsWithSameParent.first(where: { $0.filename.lowercased() == newItemFileName }),
           !collidingItem.isTrashed {
            completionHandler(nil, NSError.fileProviderErrorForCollision(with: collidingItem))
            return
        }

        let importedFileUUID = UUID().uuidString
        let importedDocumentIdentifier = NSFileProviderItemIdentifier(importedFileUUID)
        let storageUrl = FileProviderItem.createStorageUrl(
            identifier: importedDocumentIdentifier,
            filename: fileURL.lastPathComponent,
            domain: domain
        )

        fileCoordinator.coordinate(
            readingItemAt: fileURL,
            options: .withoutChanges,
            writingItemAt: storageUrl,
            options: .forReplacing,
            error: nil
        ) { readURL, writeURL in
            do {
                try FileManager.default.copyItem(at: readURL, to: writeURL)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        if accessingSecurityScopedResource {
            fileURL.stopAccessingSecurityScopedResource()
        }

        guard let parentDirectoryId = parentItemIdentifier.toFileId() else {
            fatalError("missing parentDirectoryId TODO sentry")
        }

        let importItem = UploadFileProviderItem(uploadFileUUID: importedFileUUID,
                                                parentDirectoryId: parentDirectoryId,
                                                userId: driveFileManager.drive.userId,
                                                driveId: driveFileManager.drive.id,
                                                sourceUrl: storageUrl,
                                                conflictOption: .version,
                                                shouldRemoveAfterUpload: false /* should be true actually ?*/ )
        backgroundUpload(importItem) {
            completionHandler(importItem, nil)
        }
    }

    override func renameItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        toName itemName: String,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        Log.fileProvider("renameItem")
        Task {
            guard self.uploadQueue.getUploadingFile(fileProviderItemIdentifier: itemIdentifier.rawValue) == nil else {
                Log.fileProvider("renameItem not supported while uploading", level: .error)
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            guard let fileId = itemIdentifier.toFileId(),
                  let file = self.driveFileManager.getCachedFile(id: fileId) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            // Check if file name already exists
            let item = FileProviderItem(file: file, domain: self.domain)
            let itemsWithSameParent = file.parent!.children
                .map { FileProviderItem(file: $0, domain: self.domain) } + self.fileProviderState
                .importedDocuments(forParent: item.parentItemIdentifier)
            let newItemFileName = itemName.lowercased()
            if let collidingItem = itemsWithSameParent.first(where: { $0.filename.lowercased() == newItemFileName }),
               !collidingItem.isTrashed {
                completionHandler(nil, NSError.fileProviderErrorForCollision(with: collidingItem))
                return
            }

            let proxyFile = file.proxify()
            do {
                let file = try await self.driveFileManager.rename(file: proxyFile, newName: itemName)
                completionHandler(FileProviderItem(file: file.freeze(), domain: self.domain), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func reparentItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
        newName: String?,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        Log.fileProvider("reparentItem")
        Task {
            guard self.uploadQueue.getUploadingFile(fileProviderItemIdentifier: itemIdentifier.rawValue) == nil else {
                Log.fileProvider("reparentItem not supported while uploading", level: .error)
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            guard let fileId = itemIdentifier.toFileId(),
                  let file = self.driveFileManager.getCachedFile(id: fileId),
                  let parentId = parentItemIdentifier.toFileId(),
                  let parent = self.driveFileManager.getCachedFile(id: parentId) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            let proxyFile = file.proxify()
            let proxyParent = parent.proxify()
            do {
                let (_, file) = try await self.driveFileManager.move(file: proxyFile, to: proxyParent)
                completionHandler(FileProviderItem(file: file.freeze(), domain: self.domain), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func setFavoriteRank(
        _ favoriteRank: NSNumber?,
        forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        let fileId = itemIdentifier.toFileId()
        Log.fileProvider("setFavoriteRank forItemIdentifier:\(String(describing: fileId))")
        // How should we save favourite rank in database?
        guard let fileId,
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        let item = FileProviderItem(file: file, domain: domain)
        item.favoriteRank = favoriteRank

        completionHandler(item, nil)
    }

    override func setLastUsedDate(
        _ lastUsedDate: Date?,
        forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        Log.fileProvider("setLastUsedDate forItemIdentifier")
        // kDrive doesn't support this
        completionHandler(nil, NSError.featureUnsupported)
    }

    override func setTagData(
        _ tagData: Data?,
        forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        Log.fileProvider("setTagData :\(tagData?.count) forItemIdentifier")
        // kDrive doesn't support this
        completionHandler(nil, NSError.featureUnsupported)
    }

    override func trashItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        let fileId = itemIdentifier.toFileId()
        let uploadFileId = itemIdentifier.rawValue
        Log.fileProvider("trashItem withIdentifier:\(fileId) uploadFileId:\(uploadFileId)")
        Task {
            // Cancel upload if any matching
            self.uploadQueue.cancel(uploadFileId: uploadFileId)

            guard let fileId,
                  let file = self.driveFileManager.getCachedFile(id: fileId) else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            // Make deleted file copy
            let deletedFile = file.detached()
            let item = FileProviderItem(file: deletedFile, domain: self.domain)
            item.isTrashed = true
            let proxyFile = file.proxify()

            do {
                _ = try await self.driveFileManager.delete(file: proxyFile)
                self.fileProviderState.setWorkingDocument(item, forKey: itemIdentifier)
                completionHandler(item, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func untrashItem(
        withIdentifier itemIdentifier: NSFileProviderItemIdentifier,
        toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) {
        let fileId = itemIdentifier.toFileId()
        Log.fileProvider("untrashItem withIdentifier:\(fileId)")
        Task {
            guard let fileId else {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
                return
            }

            // Trashed items are not cached so we call the API
            do {
                let file = try await self.driveFileManager.apiFetcher
                    .trashedFile(ProxyFile(driveId: self.driveFileManager.drive.id, id: fileId))
                let parent: ProxyFile?
                if let id = parentItemIdentifier?.toFileId() {
                    parent = ProxyFile(driveId: self.driveFileManager.drive.id, id: id)
                } else {
                    parent = nil
                }
                // Restore in given parent
                _ = try await self.driveFileManager.apiFetcher.restore(file: file.proxify(), in: parent)
                let item = FileProviderItem(file: file, domain: self.domain)
                if let parentItemIdentifier {
                    item.parentItemIdentifier = parentItemIdentifier
                }
                item.isTrashed = false
                self.fileProviderState.removeWorkingDocument(forKey: itemIdentifier)
                completionHandler(item, nil)

                // Signal after completionHandler
                try await self.manager.signalEnumerator(for: .workingSet)
                try await self.manager.signalEnumerator(for: item.parentItemIdentifier)
            } catch {
                completionHandler(nil, NSFileProviderError(.noSuchItem))
            }
        }
    }
}
