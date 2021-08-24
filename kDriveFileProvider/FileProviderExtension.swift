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

import CoreServices
import FileProvider
import InfomaniakLogin
import kDriveCore

class FileProviderExtensionState {
    static let shared = FileProviderExtensionState()
    var importedDocuments = [NSFileProviderItemIdentifier: FileProviderItem]()
    var workingSet = [NSFileProviderItemIdentifier: FileProviderItem]()

    func importedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem] {
        return importedDocuments.values.filter { $0.parentItemIdentifier == parentItemIdentifier }
    }

    func unenumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem] {
        let children = importedDocuments.values.filter { $0.parentItemIdentifier == parentItemIdentifier && !$0.alreadyEnumerated }
        children.forEach { $0.alreadyEnumerated = true }
        return children
    }

    func deleteAlreadyEnumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [NSFileProviderItemIdentifier] {
        let children = importedDocuments.values.filter { $0.parentItemIdentifier == parentItemIdentifier && $0.alreadyEnumerated }
        return children.compactMap { importedDocuments.removeValue(forKey: $0.itemIdentifier)?.itemIdentifier }
    }
}

class FileProviderExtension: NSFileProviderExtension {
    lazy var fileCoordinator: NSFileCoordinator = {
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = manager.providerIdentifier
        return fileCoordinator
    }()

    let accountManager: AccountManager
    lazy var driveFileManager: DriveFileManager! = setDriveFileManager()
    lazy var manager: NSFileProviderManager = {
        if let domain = domain {
            return NSFileProviderManager(for: domain) ?? .default
        }
        return .default
    }()

    private func setDriveFileManager() -> DriveFileManager? {
        if let objectId = domain?.identifier.rawValue,
           let drive = DriveInfosManager.instance.getDrive(objectId: objectId),
           let driveFileManager = accountManager.getDriveFileManager(for: drive) {
            return driveFileManager
        } else {
            return accountManager.currentDriveFileManager
        }
    }

    override init() {
        Logging.initLogging()
        InfomaniakLogin.initWith(clientId: DriveApiFetcher.clientId)
        accountManager = AccountManager.instance
        super.init()
    }

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        try isFileProviderExtensionEnabled()
        // Try to reload account if user logged in
        try updateDriveFileManager()

        if let item = FileProviderExtensionState.shared.workingSet[identifier] {
            return item
        } else if let item = FileProviderExtensionState.shared.importedDocuments[identifier] {
            return item
        } else if let fileId = identifier.toFileId(),
                  let file = driveFileManager.getCachedFile(id: fileId) {
            return FileProviderItem(file: file, domain: domain)
        } else {
            throw nsError(code: .noSuchItem)
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        if let item = FileProviderExtensionState.shared.importedDocuments[identifier] {
            return item.storageUrl
        } else if let fileId = identifier.toFileId(),
                  let file = driveFileManager.getCachedFile(id: fileId) {
            return FileProviderItem(file: file, domain: domain).storageUrl
        } else {
            return nil
        }
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        return FileProviderItem.identifier(for: url, domain: domain)
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        do {
            let fileProviderItem = try item(for: identifier)

            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try? FileManager.default.createDirectory(at: placeholderURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)

            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }

    override func itemChanged(at url: URL) {
        if let identifier = persistentIdentifierForItem(at: url),
           let item = try? item(for: identifier) as? FileProviderItem {
            backgroundUploadItem(item)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let fileId = FileProviderItem.identifier(for: url, domain: domain)?.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            if FileManager.default.fileExists(atPath: url.path) {
                completionHandler(nil)
            } else {
                completionHandler(nsError(code: .noSuchItem))
            }
            return
        }

        let item = FileProviderItem(file: file, domain: domain)

        if fileStorageIsCurrent(item: item, file: file) {
            // File is in the file provider and is the same, nothing to do...
            completionHandler(nil)
        } else {
            downloadRemoteFile(file: file, for: item, completion: completionHandler)
        }
    }

    private func isFileProviderExtensionEnabled() throws {
        guard UserDefaults.shared.isFileProviderExtensionEnabled else {
            throw nsError(code: .notAuthenticated)
        }
    }

    private func updateDriveFileManager() throws {
        if driveFileManager == nil {
            accountManager.forceReload()
            driveFileManager = setDriveFileManager()
        }
        guard driveFileManager != nil else {
            throw nsError(code: .notAuthenticated)
        }
    }

    private func fileStorageIsCurrent(item: FileProviderItem, file: File) -> Bool {
        return !file.isLocalVersionOlderThanRemote() && FileManager.default.contentsEqual(atPath: item.storageUrl.path, andPath: file.localUrl.path)
    }

    private func downloadRemoteFile(file: File, for item: FileProviderItem, completion: @escaping (Error?) -> Void) {
        if file.isLocalVersionOlderThanRemote() {
            // Prevent observing file multiple times
            guard !DownloadQueue.instance.hasOperation(for: file) else {
                completion(nil)
                return
            }

            var observationToken: ObservationToken?
            observationToken = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { _, error in
                observationToken?.cancel()
                if error != nil {
                    self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
                    completion(NSFileProviderError(.serverUnreachable))
                } else {
                    self.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
                    self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
                    completion(nil)
                }
            }
            DownloadQueue.instance.addToQueue(file: file, userId: driveFileManager.drive.userId, itemIdentifier: item.itemIdentifier)
            manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
        } else {
            copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
            manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
            completion(nil)
        }
    }

    private func copyOrReplace(sourceUrl: URL, destinationUrl: URL) {
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationUrl.path) {
                try fileManager.removeItem(at: destinationUrl)
            }
            try fileManager.copyItem(at: sourceUrl, to: destinationUrl)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }

    override func stopProvidingItem(at url: URL) {
        if let identifier = persistentIdentifierForItem(at: url),
           let item = try? item(for: identifier) as? FileProviderItem {
            if let remoteModificationDate = item.contentModificationDate,
               let localModificationDate = try? item.storageUrl.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               remoteModificationDate > localModificationDate {
                backgroundUploadItem(item) {
                    self.cleanupAt(url: url)
                }
            } else {
                cleanupAt(url: url)
            }
        } else {
            // The document isn't in realm maybe it was recently imported?
            cleanupAt(url: url)
        }
    }

    private func cleanupAt(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Handle error
        }

        // write out a placeholder to facilitate future property lookups
        providePlaceholder(at: url) { _ in
            // TODO: handle any error, do any necessary cleanup
        }
    }

    func backgroundUploadItem(_ item: FileProviderItem, completion: (() -> Void)? = nil) {
        let fileId = item.itemIdentifier.rawValue
        let uploadFile = UploadFile(
            id: fileId,
            parentDirectoryId: item.parentItemIdentifier.toFileId()!,
            userId: driveFileManager.drive.userId,
            driveId: driveFileManager.drive.id,
            url: item.storageUrl,
            name: item.filename,
            shouldRemoveAfterUpload: false)
        var observationToken: ObservationToken?
        observationToken = UploadQueue.instance.observeFileUploaded(self, fileId: fileId) { uploadedFile, _ in
            observationToken?.cancel()
            if let error = uploadedFile.error {
                item.setUploadingError(error)
            }
            completion?()
        }
        UploadQueue.instance.addToQueue(file: uploadFile, itemIdentifier: item.itemIdentifier)
    }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        try isFileProviderExtensionEnabled()
        // Try to reload account if user logged in
        try updateDriveFileManager()

        if containerItemIdentifier == .workingSet {
            return FileProviderEnumerator(containerItemIdentifier: .workingSet, driveFileManager: driveFileManager, domain: domain)
        }
        let item = try self.item(for: containerItemIdentifier)
        return FileProviderEnumerator(containerItem: item, driveFileManager: driveFileManager, domain: domain)
    }

    // MARK: - Validation

    override func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier) throws -> [NSFileProviderServiceSource] {
        let validationService = FileProviderValidationServiceSource(fileProviderExtension: self, itemIdentifier: itemIdentifier)!
        return [validationService]
    }
}

// MARK: - Convenient methods

extension FileProviderExtension {
    // Create an NSError based on the file provider error code
    func nsError(domain: String = NSFileProviderErrorDomain,
                 code: NSFileProviderError.Code,
                 userInfo dict: [String: Any]? = nil) -> NSError {
        return NSError(domain: NSFileProviderErrorDomain, code: code.rawValue, userInfo: dict)
    }
}
