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
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let fileId = parentItemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        // Call completion handler with error if the file name already exists
        let itemsWithSameParent = file.children.map { FileProviderItem(file: $0, domain: self.domain) } + FileProviderExtensionState.shared.importedDocuments(forParent: parentItemIdentifier)
        let newItemFileName = directoryName.lowercased()
        if let collidingItem = itemsWithSameParent.first(where: { $0.filename.lowercased() == newItemFileName }),
           !collidingItem.isTrashed {
            completionHandler(nil, NSError.fileProviderErrorForCollision(with: collidingItem))
            return
        }

        Task { [proxyFile = file.proxify()] in
            do {
                let directory = try await driveFileManager.createDirectory(in: proxyFile, name: directoryName, onlyForMe: false)
                completionHandler(FileProviderItem(file: directory, domain: self.domain), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        guard let fileId = itemIdentifier.toFileId() else {
            completionHandler(nsError(code: .noSuchItem))
            return
        }

        Task {
            do {
                let response = try await driveFileManager.apiFetcher.deleteDefinitely(file: ProxyFile(driveId: driveFileManager.drive.id, id: fileId))
                if response {
                    FileProviderExtensionState.shared.workingSet.removeValue(forKey: itemIdentifier)
                    self.manager.signalEnumerator(for: .workingSet) { _ in }
                    self.manager.signalEnumerator(for: itemIdentifier) { _ in }
                    completionHandler(nil)
                } else {
                    completionHandler(self.nsError(code: .serverUnreachable))
                }
            } catch {
                completionHandler(error)
            }
        }
    }

    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        let accessingSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()

        // Call completion handler with error if the file name already exists
        guard let fileId = parentItemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }
        let itemsWithSameParent = file.children.map { FileProviderItem(file: $0, domain: self.domain) } + FileProviderExtensionState.shared.importedDocuments(forParent: parentItemIdentifier)
        let newItemFileName = fileURL.lastPathComponent.lowercased()
        if let collidingItem = itemsWithSameParent.first(where: { $0.filename.lowercased() == newItemFileName }),
           !collidingItem.isTrashed {
            completionHandler(nil, NSError.fileProviderErrorForCollision(with: collidingItem))
            return
        }

        let id = UUID().uuidString
        let importedDocumentIdentifier = NSFileProviderItemIdentifier(id)
        let storageUrl = FileProviderItem.createStorageUrl(identifier: importedDocumentIdentifier, filename: fileURL.lastPathComponent, domain: domain)

        fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, writingItemAt: storageUrl, options: .forReplacing, error: nil) { readURL, writeURL in
            do {
                try FileManager.default.copyItem(at: readURL, to: writeURL)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        if accessingSecurityScopedResource {
            fileURL.stopAccessingSecurityScopedResource()
        }
        let importedItem = FileProviderItem(importedFileUrl: storageUrl, identifier: importedDocumentIdentifier, parentIdentifier: parentItemIdentifier)
        FileProviderExtensionState.shared.importedDocuments[importedDocumentIdentifier] = importedItem

        backgroundUploadItem(importedItem)

        manager.signalEnumerator(for: parentItemIdentifier) { _ in }
        completionHandler(importedItem, nil)
    }

    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        // Doc says we should do network request after renaming local file but we could end up with model desync
        if let item = FileProviderExtensionState.shared.importedDocuments[itemIdentifier] {
            item.filename = itemName
            manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
            completionHandler(item, nil)
            return
        }

        guard let fileId = itemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        // Check if file name already exists
        let item = FileProviderItem(file: file, domain: domain)
        let itemsWithSameParent = file.parent!.children.map { FileProviderItem(file: $0, domain: self.domain) } + FileProviderExtensionState.shared.importedDocuments(forParent: item.parentItemIdentifier)
        let newItemFileName = itemName.lowercased()
        if let collidingItem = itemsWithSameParent.first(where: { $0.filename.lowercased() == newItemFileName }),
           !collidingItem.isTrashed {
            completionHandler(nil, NSError.fileProviderErrorForCollision(with: collidingItem))
            return
        }

        Task { [proxyFile = file.proxify()] in
            do {
                let file = try await driveFileManager.rename(file: proxyFile, newName: itemName)
                completionHandler(FileProviderItem(file: file.freeze(), domain: self.domain), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        if let item = FileProviderExtensionState.shared.importedDocuments[itemIdentifier] {
            item.parentItemIdentifier = parentItemIdentifier
            manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
            completionHandler(item, nil)
            return
        }

        guard let fileId = itemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId),
              let parentId = parentItemIdentifier.toFileId(),
              let parent = driveFileManager.getCachedFile(id: parentId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        Task { [proxyFile = file.proxify(), proxyParent = parent.proxify()] in
            do {
                let (_, file) = try await driveFileManager.move(file: proxyFile, to: proxyParent)
                completionHandler(FileProviderItem(file: file.freeze(), domain: domain), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func setFavoriteRank(_ favoriteRank: NSNumber?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        // How should we save favorite rank in database?
        guard let fileId = itemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        let item = FileProviderItem(file: file, domain: domain)
        item.favoriteRank = favoriteRank

        completionHandler(item, nil)
    }

    override func setLastUsedDate(_ lastUsedDate: Date?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        // kDrive doesn't support this
        completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError))
    }

    override func setTagData(_ tagData: Data?, forItemIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        // kDrive doesn't support this
        completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError))
    }

    override func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let fileId = itemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            completionHandler(nil, NSFileProviderError(.noSuchItem))
            return
        }

        // Make deleted file copy
        let deletedFile = file.detached()
        let item = FileProviderItem(file: deletedFile, domain: domain)
        item.isTrashed = true

        Task { [proxyFile = file.proxify()] in
            do {
                _ = try await driveFileManager.delete(file: proxyFile)
                FileProviderExtensionState.shared.workingSet[itemIdentifier] = item
                completionHandler(item, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    override func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        guard let fileId = itemIdentifier.toFileId() else {
            completionHandler(nil, nsError(code: .noSuchItem))
            return
        }

        // Trashed items are not cached so we call the API
        Task {
            do {
                let file = try await driveFileManager.apiFetcher.trashedFile(ProxyFile(driveId: driveFileManager.drive.id, id: fileId))
                let parent: ProxyFile?
                if let id = parentItemIdentifier?.toFileId() {
                    parent = ProxyFile(driveId: self.driveFileManager.drive.id, id: id)
                } else {
                    parent = nil
                }
                // Restore in given parent
                _ = try await self.driveFileManager.apiFetcher.restore(file: file.proxify(), in: parent)
                let item = FileProviderItem(file: file, domain: self.domain)
                if let parentItemIdentifier = parentItemIdentifier {
                    item.parentItemIdentifier = parentItemIdentifier
                }
                item.isTrashed = false
                FileProviderExtensionState.shared.workingSet.removeValue(forKey: itemIdentifier)
                self.manager.signalEnumerator(for: .workingSet) { _ in }
                self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
                completionHandler(item, nil)
            } catch {
                completionHandler(nil, self.nsError(code: .noSuchItem))
            }
        }
    }
}
