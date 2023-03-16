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

final class FileProviderExtension: NSFileProviderExtension {
    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook()

    /// Something to enqueue async await tasks in a serial manner.
    let asyncAwaitQueue = TaskQueue()

    @LazyInjectService var uploadQueue: UploadQueue
    @LazyInjectService var fileProviderState: FileProviderExtensionAdditionalStatable

    lazy var fileCoordinator: NSFileCoordinator = {
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.purposeIdentifier = manager.providerIdentifier
        return fileCoordinator
    }()

    @LazyInjectService var accountManager: AccountManageable
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

    // MARK: - NSFileProviderExtension Override

    override init() {
        FileProviderLog("init")

        // Load types into realm so it does not scan all types and uses more that 20MiB or ram.
        _ = try? Realm(configuration: DriveFileManager.constants.uploadsRealmConfiguration)

        Logging.initLogging()
        super.init()
    }

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        FileProviderLog("item(for identifier:)")
        try isFileProviderExtensionEnabled()
        // Try to reload account if user logged in
        try updateDriveFileManager()

        if let item = fileProviderState.getWorkingDocument(forKey: identifier) {
            return item
        } else if let item = fileProviderState.getImportedDocument(forKey: identifier) {
            return item
        } else if let fileId = identifier.toFileId(),
                  let file = driveFileManager.getCachedFile(id: fileId) {
            return FileProviderItem(file: file, domain: domain)
        } else {
            throw nsError(code: .noSuchItem)
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        FileProviderLog("urlForItem(withPersistentIdentifier identifier:)")
        if let item = fileProviderState.getImportedDocument(forKey: identifier) {
            return item.storageUrl
        } else if let fileId = identifier.toFileId(),
                  let file = driveFileManager.getCachedFile(id: fileId) {
            return FileProviderItem(file: file, domain: domain).storageUrl
        } else {
            return nil
        }
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        FileProviderLog("persistentIdentifierForItem at url:\(url)")
        return FileProviderItem.identifier(for: url, domain: domain)
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        FileProviderLog("providePlaceholder at url:\(url)")
        enqueue {
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
        FileProviderLog("itemChanged at url:\(url)")
        enqueue {
            if let identifier = self.persistentIdentifierForItem(at: url),
               let item = try? self.item(for: identifier) as? FileProviderItem {
                self.backgroundUploadItem(item)
            }
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        FileProviderLog("startProvidingItem at url:\(url)")
        enqueue {
            guard let fileId = FileProviderItem.identifier(for: url, domain: self.domain)?.toFileId(),
                  let file = self.driveFileManager.getCachedFile(id: fileId) else {
                if FileManager.default.fileExists(atPath: url.path) {
                    completionHandler(nil)
                } else {
                    completionHandler(self.nsError(code: .noSuchItem))
                }
                return
            }

            let item = FileProviderItem(file: file, domain: self.domain)

            if self.fileStorageIsCurrent(item: item, file: file) {
                // File is in the file provider and is the same, nothing to do...
                completionHandler(nil)
            } else {
                self.downloadRemoteFile(file: file, for: item, completion: completionHandler)
            }
        }
    }

    override func stopProvidingItem(at url: URL) {
        FileProviderLog("stopProvidingItem at url:\(url)")
        enqueue {
            if let identifier = self.persistentIdentifierForItem(at: url),
               let item = try? self.item(for: identifier) as? FileProviderItem {
                if let remoteModificationDate = item.contentModificationDate,
                   let localModificationDate = try? item.storageUrl.resourceValues(forKeys: [.contentModificationDateKey])
                   .contentModificationDate,
                   remoteModificationDate > localModificationDate {
                    self.backgroundUploadItem(item) {
                        self.cleanupAt(url: url)
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
        FileProviderLog("isFileProviderExtensionEnabled")
        guard UserDefaults.shared.isFileProviderExtensionEnabled else {
            throw nsError(code: .notAuthenticated)
        }
    }

    private func updateDriveFileManager() throws {
        FileProviderLog("updateDriveFileManager")
        if driveFileManager == nil {
            accountManager.forceReload()
            driveFileManager = setDriveFileManager()
        }
        guard driveFileManager != nil else {
            throw nsError(code: .notAuthenticated)
        }
    }

    private func fileStorageIsCurrent(item: FileProviderItem, file: File) -> Bool {
        FileProviderLog("fileStorageIsCurrent item file:\(file.id)")
        return !file.isLocalVersionOlderThanRemote && FileManager.default.contentsEqual(
            atPath: item.storageUrl.path,
            andPath: file.localUrl.path
        )
    }

    private func downloadRemoteFile(file: File, for item: FileProviderItem, completion: @escaping (Error?) -> Void) {
        FileProviderLog("downloadRemoteFile file:\(file.id)")
        enqueue {
            // LocalVersion is OlderThanRemote
            if file.isLocalVersionOlderThanRemote {
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
                        do {
                            try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
                            self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
                            completion(nil)
                        } catch {
                            completion(error)
                        }
                    }
                }
                DownloadQueue.instance.addToQueue(
                    file: file,
                    userId: self.driveFileManager.drive.userId,
                    itemIdentifier: item.itemIdentifier
                )
                self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
            }
            // LocalVersion is _not_ OlderThanRemote
            else {
                do {
                    try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
                    self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
        }
    }

    private func cleanupAt(url: URL) {
        FileProviderLog("cleanupAt url:\(url)")
        enqueue {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                // Handle error
            }

            // write out a placeholder to facilitate future property lookups
            self.providePlaceholder(at: url) { _ in
                // TODO: handle any error, do any necessary cleanup
            }
        }
    }

    func backgroundUploadItem(_ item: FileProviderItem, completion: (() -> Void)? = nil) {
        FileProviderLog("backgroundUploadItem")
        enqueue {
            let fileId = item.itemIdentifier.rawValue
            let uploadFile = UploadFile(
                id: fileId,
                parentDirectoryId: item.parentItemIdentifier.toFileId()!,
                userId: self.driveFileManager.drive.userId,
                driveId: self.driveFileManager.drive.id,
                url: item.storageUrl,
                name: item.filename,
                conflictOption: .version,
                shouldRemoveAfterUpload: false,
                initiatedFromFileManager: true
            )
            var observationToken: ObservationToken?
            observationToken = self.uploadQueue.observeFileUploaded(self, fileId: fileId) { uploadedFile, _ in
                observationToken?.cancel()
                defer {
                    self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in
                        completion?()
                    }
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
            self.uploadQueue.saveToRealmAndAddToQueue(file: uploadFile, itemIdentifier: item.itemIdentifier)
        }
    }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        FileProviderLog("enumerator for :\(containerItemIdentifier.rawValue)")
        try isFileProviderExtensionEnabled()
        // Try to reload account if user logged in
        try updateDriveFileManager()

        if containerItemIdentifier == .workingSet {
            return FileProviderEnumerator(
                containerItemIdentifier: .workingSet,
                driveFileManager: driveFileManager,
                domain: domain
            )
        }
        let item = try self.item(for: containerItemIdentifier)
        return FileProviderEnumerator(containerItem: item, driveFileManager: driveFileManager, domain: domain)
    }

    // MARK: - Validation

    override func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier) throws
        -> [NSFileProviderServiceSource] {
        FileProviderLog("supportedServiceSources for :\(itemIdentifier.rawValue)")
        let validationService = FileProviderValidationServiceSource(fileProviderExtension: self, itemIdentifier: itemIdentifier)!
        return [validationService]
    }

    // MARK: - Async

    /// Enqueue an async/await closure in the underlaying serial execution queue.
    /// - Parameter task: A closure with async await code to be dispatched
    func enqueue(_ task: @escaping () async throws -> Void) {
        Task {
            try await asyncAwaitQueue.enqueue(asap: false) {
                try await task()
            }
        }
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
