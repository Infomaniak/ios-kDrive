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
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import RealmSwift

extension NSError {
    static let featureUnsupported = NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError)
}

extension DriveFileManager {
    func getCachedFile(itemIdentifier: NSFileProviderItemIdentifier,
                       freeze: Bool = true,
                       using realm: Realm? = nil) throws -> File {
        guard let fileId = itemIdentifier.toFileId(),
              let file = getCachedFile(id: fileId, freeze: freeze, using: realm) else {
            throw NSFileProviderError(.noSuchItem)
        }

        return file
    }
}

final class FileProviderExtension: NSFileProviderExtension {
    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook()

    @LazyInjectService var uploadQueue: UploadQueueable
    @LazyInjectService var uploadQueueObservable: UploadQueueObservable
    @LazyInjectService var fileProviderState: FileProviderExtensionAdditionalStatable

    lazy var fileCoordinator: NSFileCoordinator = {
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = manager.providerIdentifier
        return fileCoordinator
    }()

    @LazyInjectService var accountManager: AccountManageable
    lazy var driveFileManager: DriveFileManager! = setDriveFileManager()
    lazy var manager: NSFileProviderManager = {
        if let domain {
            return NSFileProviderManager(for: domain) ?? .default
        }
        return .default
    }()

    private func setDriveFileManager() -> DriveFileManager? {
        var currentDriveFileManager: DriveFileManager?
        if let objectId = domain?.identifier.rawValue,
           let drive = DriveInfosManager.instance.getDrive(objectId: objectId),
           let driveFileManager = accountManager.getDriveFileManager(for: drive) {
            currentDriveFileManager = driveFileManager
        } else {
            currentDriveFileManager = accountManager.currentDriveFileManager
        }

        guard let currentDriveFileManager else { return nil }

        return currentDriveFileManager.instanceWith(context: .fileProvider)
    }

    // MARK: - NSFileProviderExtension Override

    override init() {
        Log.fileProvider("init")

        // Load types into realm so it does not scan all types and uses more that 20MiB or ram.
        _ = try? Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration)

        Logging.initLogging()
        super.init()
    }

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        Log.fileProvider("item for identifier")
        try isFileProviderExtensionEnabled()
        // Try to reload account if user logged in
        try updateDriveFileManager()

        if let item = fileProviderState.getWorkingDocument(forKey: identifier) {
            Log.fileProvider("item for identifier - Working Document")
            return item
        } else if let item = fileProviderState.getImportedDocument(forKey: identifier) {
            Log.fileProvider("item for identifier - Imported Document")
            return item
        } else if let fileId = identifier.toFileId(),
                  let file = driveFileManager.getCachedFile(id: fileId) {
            Log.fileProvider("item for identifier - File:\(fileId)")
            return FileProviderItem(file: file, domain: domain)
        } else {
            Log.fileProvider("item for identifier - nsError(code: .noSuchItem)")
            throw NSFileProviderError(.noSuchItem)
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        Log.fileProvider("urlForItem(withPersistentIdentifier identifier:)")
        if let item = fileProviderState.getImportedDocument(forKey: identifier) {
            return item.storageUrl
        } else if let fileId = identifier.toFileId(),
                  let file = driveFileManager.getCachedFile(id: fileId) {
            let item = FileProviderItem(file: file, domain: domain)
            guard !item.isDirectory else {
                // TODO: Support download folder, recursively download content
                return nil
            }

            return item.storageUrl
        } else {
            return nil
        }
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        Log.fileProvider("persistentIdentifierForItem at url:\(url)")
        return FileProviderItem.identifier(for: url, domain: domain)
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        Log.fileProvider("providePlaceholder at url:\(url)")
        Task {
            guard let identifier = self.persistentIdentifierForItem(at: url) else {
                completionHandler(NSFileProviderError(.noSuchItem))
                return
            }

            do {
                let fileProviderItem = try self.item(for: identifier)

                let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
                try? FileManager.default.createDirectory(
                    at: placeholderURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: fileProviderItem)

                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func itemChanged(at url: URL) {
        Log.fileProvider("itemChanged at url:\(url)")
        Task {
            if let identifier = self.persistentIdentifierForItem(at: url),
               let item = try? self.item(for: identifier) as? FileProviderItem {
                self.backgroundUploadItem(item)
            }
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        Log.fileProvider("startProvidingItem at url:\(url)")
        Task {
            guard let fileId = FileProviderItem.identifier(for: url, domain: self.domain)?.toFileId(),
                  let file = self.driveFileManager.getCachedFile(id: fileId) else {
                if FileManager.default.fileExists(atPath: url.path) {
                    completionHandler(nil)
                } else {
                    completionHandler(NSFileProviderError(.noSuchItem))
                }
                return
            }

            let item = FileProviderItem(file: file, domain: self.domain)

            if self.fileStorageIsCurrent(item: item, file: file) {
                // File is in the file provider and is the same, nothing to do...
                completionHandler(nil)
            } else {
                self.downloadRemoteFile(file, for: item, completion: completionHandler)
            }
        }
    }

    override func stopProvidingItem(at url: URL) {
        Log.fileProvider("stopProvidingItem at url:\(url)")
        Task {
            if let identifier = self.persistentIdentifierForItem(at: url),
               let item = try? self.item(for: identifier) as? FileProviderItem {
                if let remoteModificationDate = item.contentModificationDate,
                   let localModificationDate = try? item.storageUrl.resourceValues(forKeys: [.contentModificationDateKey])
                   .contentModificationDate,
                   remoteModificationDate > localModificationDate {
                    self.backgroundUploadItem(item) {
                        self.cleanupAt(url: url, parentItemIdentifier: item.parentItemIdentifier)
                    }
                } else {
                    self.cleanupAt(url: url)
                }
            } else {
                // The document isn't in realm maybe it was recently imported?
                self.cleanupAt(url: url)
            }
        }
    }

    // MARK: - Private

    private func isFileProviderExtensionEnabled() throws {
        Log.fileProvider("isFileProviderExtensionEnabled")
        guard UserDefaults.shared.isFileProviderExtensionEnabled else {
            throw NSFileProviderError(.notAuthenticated)
        }
    }

    private func updateDriveFileManager() throws {
        Log.fileProvider("updateDriveFileManager")
        if driveFileManager == nil {
            accountManager.forceReload()
            driveFileManager = setDriveFileManager()
        }
        guard driveFileManager != nil else {
            throw NSFileProviderError(.notAuthenticated)
        }
    }

    private func fileStorageIsCurrent(item: FileProviderItem, file: File) -> Bool {
        Log.fileProvider("fileStorageIsCurrent item file:\(file.id)")
        return !file.isLocalVersionOlderThanRemote && FileManager.default.contentsEqual(
            atPath: item.storageUrl.path,
            andPath: file.localUrl.path
        )
    }

    private func downloadRemoteFile(_ file: File, for item: FileProviderItem, completion: @escaping (Error?) -> Void) {
        Log.fileProvider("downloadRemoteFile file:\(file.id)")
        Task {
            // LocalVersion is OlderThanRemote
            if file.isLocalVersionOlderThanRemote {
                try await self.downloadFreshRemoteFile(file, for: item, completion: completion)
            }
            // LocalVersion is _not_ OlderThanRemote
            else {
                await self.saveFreshLocalFile(file, for: item, completion: completion)
            }
        }
    }

    private func downloadFreshRemoteFile(
        _ file: File,
        for item: FileProviderItem,
        completion: @escaping (Error?) -> Void
    ) async throws {
        // Prevent observing file multiple times
        guard !DownloadQueue.instance.hasOperation(for: file) else {
            completion(nil)
            return
        }

        defer {
            self.signalEnumerator(for: item.parentItemIdentifier)
        }

        var observationToken: ObservationToken?
        observationToken = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { _, error in
            observationToken?.cancel()
            item.isDownloading = false

            defer {
                self.signalEnumerator(for: item.parentItemIdentifier)
            }

            if error != nil {
                item.isDownloaded = false
                completion(NSFileProviderError(.serverUnreachable))
            } else {
                do {
                    try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
                    item.isDownloaded = true
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }

        DownloadQueue.instance.addToQueue(
            file: file,
            userId: driveFileManager.drive.userId,
            itemIdentifier: item.itemIdentifier
        )
    }

    private func saveFreshLocalFile(_ file: File, for item: FileProviderItem, completion: @escaping (Error?) -> Void) async {
        do {
            try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
            completion(nil)
        } catch {
            completion(error)
        }
        signalEnumerator(for: item.parentItemIdentifier)
    }

    private func cleanupAt(url: URL, parentItemIdentifier: NSFileProviderItemIdentifier? = nil) {
        Log.fileProvider("cleanupAt url:\(url)")
        Task {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                // Handle error
            }

            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url) { _ in
                // TODO: handle any error, do any necessary cleanup
            }

            self.signalEnumerator(for: parentItemIdentifier)
        }
    }

    func backgroundUploadItem(_ item: FileProviderItem, completion: (() -> Void)? = nil) {
        let fileProviderItemIdentifier = item.itemIdentifier.rawValue
        Log.fileProvider("backgroundUploadItem fileProviderItemIdentifier:\(fileProviderItemIdentifier)")
        Task {
            let uploadFile = UploadFile(
                parentDirectoryId: item.parentItemIdentifier.toFileId()!,
                userId: self.driveFileManager.drive.userId,
                driveId: self.driveFileManager.drive.id,
                fileProviderItemIdentifier: fileProviderItemIdentifier,
                url: item.storageUrl,
                name: item.filename,
                conflictOption: .version,
                shouldRemoveAfterUpload: false,
                initiatedFromFileManager: true
            )

            var observationToken: ObservationToken?
            observationToken = self.uploadQueueObservable.observeFileUploaded(self, fileId: uploadFile.id) { uploadedFile, _ in
                observationToken?.cancel()
                defer {
                    completion?()
                    self.signalEnumerator(for: item.parentItemIdentifier)
                }

                item.isUploading = false
                item.alreadyEnumerated = true
                if let error = uploadedFile.error {
                    item.setUploadingError(error)
                    item.isUploaded = false
                    return
                }

                self.fileProviderState.removeWorkingDocument(forKey: item.itemIdentifier)
            }

            _ = self.uploadQueue.saveToRealm(uploadFile, itemIdentifier: item.itemIdentifier, addToQueue: true)
        }
    }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        Log.fileProvider("enumerator for :\(containerItemIdentifier.rawValue)")
        try isFileProviderExtensionEnabled()
        // Try to reload account if user logged in
        try updateDriveFileManager()

        if containerItemIdentifier == .workingSet {
            return WorkingSetEnumerator(driveFileManager: driveFileManager, domain: domain)
        } else if containerItemIdentifier == .rootContainer {
            return RootEnumerator(driveFileManager: driveFileManager, domain: domain)
        }

        guard let fileId = containerItemIdentifier.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            throw NSFileProviderError(.noSuchItem)
        }

        if file.isDirectory {
            return DirectoryEnumerator(
                containerItemIdentifier: containerItemIdentifier,
                driveFileManager: driveFileManager,
                domain: domain
            )
        }

        throw NSError.featureUnsupported
    }

    // MARK: - Validation

    override func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier) throws
        -> [NSFileProviderServiceSource] {
        Log.fileProvider("supportedServiceSources for :\(itemIdentifier.rawValue)")
        let validationService = FileProviderValidationServiceSource(fileProviderExtension: self, itemIdentifier: itemIdentifier)!
        return [validationService]
    }
}
