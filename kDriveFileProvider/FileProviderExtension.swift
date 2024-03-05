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
    private let dependencyInjectionHook = EarlyDIHook(context: .fileProviderExtension)

    /// Something to enqueue async await tasks in a serial manner.
    let asyncAwaitQueue = TaskQueue()

    /// Restart the dedicated `FileManager` upload queue on init
    @InjectService var uploadQueue: UploadQueueable

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
            throw nsError(code: .noSuchItem)
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        Log.fileProvider("urlForItem(withPersistentIdentifier identifier:)")
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
        Log.fileProvider("persistentIdentifierForItem at url:\(url)")
        return FileProviderItem.identifier(for: url, domain: domain)
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        Log.fileProvider("providePlaceholder at url:\(url)")
        guard let identifier = persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        do {
            let fileProviderItem = try item(for: identifier)

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

    override func itemChanged(at url: URL) {
        Log.fileProvider("itemChanged at url:\(url)")
        if let identifier = persistentIdentifierForItem(at: url),
           let item = try? item(for: identifier) as? FileProviderItem {
            backgroundUploadItem(item)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        Log.fileProvider("startProvidingItem at url:\(url)")
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
            downloadRemoteFile(file, for: item, completion: completionHandler)
        }
    }

    override func stopProvidingItem(at url: URL) {
        Log.fileProvider("stopProvidingItem at url:\(url)")
        if let identifier = persistentIdentifierForItem(at: url),
           let item = try? item(for: identifier) as? FileProviderItem {
            if let remoteModificationDate = item.contentModificationDate,
               let localModificationDate = try? item.storageUrl.resourceValues(forKeys: [.contentModificationDateKey])
               .contentModificationDate,
               remoteModificationDate > localModificationDate {
                backgroundUploadItem(item) {
                    self.cleanupAt(url: url, identifier: item.parentItemIdentifier)
                }
            } else {
                cleanupAt(url: url)
            }
        } else {
            // The document isn't in realm maybe it was recently imported?
            cleanupAt(url: url)
        }
    }

    // MARK: - Private

    private func isFileProviderExtensionEnabled() throws {
        Log.fileProvider("isFileProviderExtensionEnabled")
        guard UserDefaults.shared.isFileProviderExtensionEnabled else {
            throw nsError(code: .notAuthenticated)
        }
    }

    private func updateDriveFileManager() throws {
        Log.fileProvider("updateDriveFileManager")
        if driveFileManager == nil {
            accountManager.forceReload()
            driveFileManager = setDriveFileManager()
        }
        guard driveFileManager != nil else {
            throw nsError(code: .notAuthenticated)
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
        // LocalVersion is OlderThanRemote
        if file.isLocalVersionOlderThanRemote {
            downloadFreshRemoteFile(file, for: item, completion: completion)
        }
        // LocalVersion is _not_ OlderThanRemote
        else {
            saveFreshLocalFile(file, for: item, completion: completion)
        }
    }

    private func downloadFreshRemoteFile(
        _ file: File,
        for item: FileProviderItem,
        completion: @escaping (Error?) -> Void
    ) {
        Log.fileProvider("downloadFreshRemoteFile \(file.id)")
        // Prevent observing file multiple times
        guard !DownloadQueue.instance.hasOperation(for: file.id) else {
            completion(nil)
            return
        }

        let itemParentItemIdentifier = item.parentItemIdentifier
        var observationToken: ObservationToken?
        observationToken = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { _, error in
            observationToken?.cancel()
            Log.fileProvider("downloadFreshRemoteFile observeFileDownloaded")
            defer {
                Log.fileProvider("downloadFreshRemoteFile observeFileDownloaded signalUpdate")
                self.signalFileProviderDaemon(identifier: itemParentItemIdentifier)
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
            itemIdentifier: itemParentItemIdentifier
        )
    }

    private func saveFreshLocalFile(_ file: File, for item: FileProviderItem, completion: @escaping (Error?) -> Void) {
        Log.fileProvider("saveFreshLocalFile")
        do {
            try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
            completion(nil)
        } catch {
            completion(error)
        }
    }

    private func cleanupAt(url: URL, identifier: NSFileProviderItemIdentifier? = nil) {
        Log.fileProvider("cleanupAt url:\(url)")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Log.fileProvider("cleanupAt error:\(error)", level: .error)
            // TODO: handle any error, do any necessary cleanup
        }

        // write out a placeholder to facilitate future property lookups
        providePlaceholder(at: url) { error in
            guard let error else {
                return
            }

            Log.fileProvider("providePlaceholder error:\(error.localizedDescription)", level: .error)
            // TODO: handle any error, do any necessary cleanup
        }
    }

    func backgroundUploadItem(_ item: FileProviderItem, completion: (() -> Void)? = nil) {
        let fileProviderItemIdentifier = item.itemIdentifier.rawValue
        Log.fileProvider("backgroundUploadItem fileProviderItemIdentifier:\(fileProviderItemIdentifier)")
        let uploadFile = UploadFile(
            parentDirectoryId: item.parentItemIdentifier.toFileId()!,
            userId: driveFileManager.drive.userId,
            driveId: driveFileManager.drive.id,
            fileProviderItemIdentifier: fileProviderItemIdentifier,
            url: item.storageUrl,
            name: item.filename,
            conflictOption: .version,
            shouldRemoveAfterUpload: false
        )

        var observationToken: ObservationToken?
        observationToken = uploadQueueObservable.observeFileUploaded(self, fileId: uploadFile.id) { uploadedFile, _ in
            observationToken?.cancel()

            item.isUploading = false
            item.alreadyEnumerated = true
            if let error = uploadedFile.error {
                item.setUploadingError(error)
                item.isUploaded = false
                return
            }

            self.fileProviderState.removeWorkingDocument(forKey: item.itemIdentifier)
            completion?()
            self.signalFileProviderDaemon(item: item)
        }

        uploadQueue.resumeAllOperations()
        _ = uploadQueue.saveToRealm(uploadFile, itemIdentifier: item.itemIdentifier, addToQueue: true)
    }

    // MARK: - Enumeration

    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        Log.fileProvider("enumerator for :\(containerItemIdentifier.rawValue)")
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
        let item = try item(for: containerItemIdentifier)
        return FileProviderEnumerator(containerItem: item, driveFileManager: driveFileManager, domain: domain)
    }

    // MARK: - Validation

    override func supportedServiceSources(for itemIdentifier: NSFileProviderItemIdentifier) throws
        -> [NSFileProviderServiceSource] {
        Log.fileProvider("supportedServiceSources for :\(itemIdentifier.rawValue)")
        let validationService = FileProviderValidationServiceSource(fileProviderExtension: self, itemIdentifier: itemIdentifier)!
        return [validationService]
    }
}

// MARK: - FileProviderDaemon signal helpers

extension FileProviderExtension {
    func asyncSignalFileProviderDaemon(item: NSFileProviderItem?) async throws {
        try await asyncSignalFileProviderDaemon(itemIdentifier: item?.parentItemIdentifier)
    }

    func asyncSignalFileProviderDaemon(itemIdentifier: NSFileProviderItemIdentifier?) async throws {
        Log.fileProvider("asyncSignalFileProviderDaemon(identifier :\(itemIdentifier?.rawValue)")
        try await manager.signalEnumerator(for: .workingSet)
        if let itemIdentifier {
            try await manager.signalEnumerator(for: itemIdentifier)
        }
    }

    func signalFileProviderDaemon(item: NSFileProviderItem?) {
        signalFileProviderDaemon(identifier: item?.parentItemIdentifier)
    }

    func signalFileProviderDaemon(identifier: NSFileProviderItemIdentifier?, function: String = #function) {
        Log.fileProvider("signalFileProviderDaemon(identifier :\(identifier?.rawValue)")
        manager.signalEnumerator(for: .workingSet) { _ in }
        if let identifier {
            manager.signalEnumerator(for: identifier) { _ in }
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
