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
                       using realm: Realm) throws -> File {
        guard let fileId = itemIdentifier.toFileId(),
              let file = getCachedFile(id: fileId, freeze: freeze, using: realm) else {
            throw NSFileProviderError(.noSuchItem)
        }

        return file
    }

    func getCachedFile(itemIdentifier: NSFileProviderItemIdentifier,
                       freeze: Bool = true) throws -> File {
        var file: File?
        readOnlyTransaction { realm in
            file = try? getCachedFile(itemIdentifier: itemIdentifier, freeze: freeze, using: realm)
        }

        guard let file else {
            throw NSFileProviderError(.noSuchItem)
        }

        return file
    }
}

final class FileProviderExtension: NSFileProviderExtension {
    /// Making sure the DI is registered at a very early stage of the app launch.
    private let dependencyInjectionHook = EarlyDIHook(context: .fileProviderExtension)

    /// Restart the dedicated `FileManager` upload queue on init
    @InjectService var uploadQueue: UploadQueueable

    @LazyInjectService var uploadQueueObservable: UploadQueueObservable
    @LazyInjectService var fileProviderService: FileProviderServiceable

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

        // TODO: working set in DB if workingSet return corresponding item

        // Read from upload queue
        if let uploadingFile = uploadQueue.getUploadingFile(fileProviderItemIdentifier: identifier.rawValue) {
            Log.fileProvider("item for identifier - Uploading file")
            let uploadingItem = uploadingFile.toFileProviderItem(parent: nil, domain: domain)
            return uploadingItem
        }

        // Read form uploaded UploadFiles
        else if let uploadedFile = uploadQueue.getUploadedFile(fileProviderItemIdentifier: identifier.rawValue),
                let remoteFileId = uploadedFile.remoteFileId {
            guard let file = driveFileManager.getCachedFile(id: remoteFileId) else {
                Log.fileProvider("Unable to bridge UploadFile \(uploadedFile.id) to File \(remoteFileId)", level: .error)
                throw NSFileProviderError(.noSuchItem)
            }

            Log.fileProvider("item for identifier - mapped File  \(remoteFileId) from uploaded UploadFile")
            let item = file.toFileProviderItem(parent: nil, domain: domain)
            return item
        }

        // Read Files DB
        else if let fileId = identifier.toFileId(),
                let file = driveFileManager.getCachedFile(id: fileId) {
            Log.fileProvider("item for identifier - File:\(fileId)")
            let item = file.toFileProviderItem(parent: nil, domain: domain)
            return item
        }

        // did not match anything
        Log.fileProvider("item for identifier - nsError(code: .noSuchItem)", level: .error)
        throw NSFileProviderError(.noSuchItem)
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        Log.fileProvider("urlForItem(withPersistentIdentifier identifier:)")

        // Read from upload queue
        if let item = uploadQueue.getUploadingFile(fileProviderItemIdentifier: identifier.rawValue) {
            Log.fileProvider("urlForItem - Uploading file")
            return item.pathURL
        }

        // Read from uploaded UploadFile
        else if let uploadedFile = uploadQueue.getUploadedFile(fileProviderItemIdentifier: identifier.rawValue) {
            Log.fileProvider("urlForItem - Uploaded file")
            if let remoteFileId = uploadedFile.remoteFileId {
                guard let file = driveFileManager.getCachedFile(id: remoteFileId) else {
                    Log.fileProvider("urlForItem - Unable to bridge UploadFile to File \(remoteFileId)", level: .error)
                    return nil
                }

                return FileProviderItem.getStorageUrl(file: file, domain: domain)
            }
        }

        // Read form Files DB
        else if let fileId = identifier.toFileId(),
                let file = driveFileManager.getCachedFile(id: fileId) {
            Log.fileProvider("urlForItem - in database")
            return FileProviderItem.getStorageUrl(file: file, domain: domain)
        }

        // Did not match
        Log.fileProvider("urlForItem - no match", level: .error)
        return nil
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        Log.fileProvider("persistentIdentifierForItem at url:\(url)")
        return fileProviderService.identifier(for: url, domain: domain)
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
           let uploadItem = try? item(for: identifier) as? UploadFileProviderItem {
            backgroundUpload(uploadItem)
        } else {
            Log.fileProvider("itemChanged lookup failed for :\(url)", level: .error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        Log.fileProvider("startProvidingItem at url:\(url)")
        guard let fileId = fileProviderService.identifier(for: url, domain: domain)?.toFileId(),
              let file = driveFileManager.getCachedFile(id: fileId) else {
            if FileManager.default.fileExists(atPath: url.path) {
                completionHandler(nil)
            } else {
                completionHandler(NSFileProviderError(.noSuchItem))
            }
            return
        }

        guard let item = file.toFileProviderItem(parent: nil, domain: domain) as? FileProviderItem else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }

        if fileStorageIsCurrent(item: item, file: file) {
            // File is in the file provider and is the same, nothing to do...
            completionHandler(nil)
        } else {
            downloadRemoteFile(file, for: item, completion: completionHandler)
        }
    }

    override func stopProvidingItem(at url: URL) {
        Log.fileProvider("stopProvidingItem at url:\(url)")

        cleanupAt(url: url)
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
        // Local copy exists OR LocalVersion is OlderThanRemote
        if !file.fullyDownloaded || file.isLocalVersionOlderThanRemote {
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
        Log.fileProvider("downloadFreshRemoteFile file:\(file.id)")
        // Prevent observing file multiple times
        guard !DownloadQueue.instance.hasOperation(for: file.id) else {
            Log.fileProvider("downloadFreshRemoteFile in queue, skip", level: .error)
            completion(nil)
            return
        }

        var observationToken: ObservationToken?
        observationToken = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { _, error in
            observationToken?.cancel()
            observationToken = nil

            defer {
                self.manager.signalEnumerator(for: .workingSet) { _ in }
                self.manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
            }

            guard error == nil else {
                completion(NSFileProviderError(.serverUnreachable))
                return
            }

            do {
                try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
                Log.fileProvider("downloadRemoteFile completion")
                completion(nil)
            } catch {
                Log.fileProvider("downloadRemoteFile error:\(error)", level: .error)
                completion(error)
            }
        }

        DownloadQueue.instance.addToQueue(
            file: file,
            userId: driveFileManager.drive.userId,
            itemIdentifier: item.itemIdentifier
        )
    }

    private func saveFreshLocalFile(_ file: File, for item: FileProviderItem, completion: @escaping (Error?) -> Void) {
        Log.fileProvider("saveFreshLocalFile file:\(file.id)")
        defer {
            manager.signalEnumerator(for: .workingSet) { _ in }
            manager.signalEnumerator(for: item.parentItemIdentifier) { _ in }
        }

        do {
            try FileManager.default.copyOrReplace(sourceUrl: file.localUrl, destinationUrl: item.storageUrl)
            completion(nil)
        } catch {
            completion(error)
        }
    }

    private func cleanupAt(url: URL) {
        Log.fileProvider("cleanupAt url:\(url)")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Log.fileProvider("cleanupAt failed to removeItem:\(error)", level: .error)
            // Handle error
        }

        // write out a placeholder to facilitate future property lookups
        providePlaceholder(at: url) { _ in
            // TODO: handle any error, do any necessary cleanup
        }
    }

    func backgroundUpload(_ uploadFileProviderItem: UploadFileProviderItem, completion: (() -> Void)? = nil) {
        Log.fileProvider("backgroundUploadItem fileProviderItemIdentifier:\(uploadFileProviderItem.itemIdentifier.rawValue)")

        let uploadFile = uploadFileProviderItem.toUploadFile

        // Observe queue for upload completion
        var observationToken: ObservationToken?
        observationToken = uploadQueueObservable.observeFileUploaded(self, fileId: uploadFile.id) { uploadedFile, _ in
            observationToken?.cancel()
            observationToken = nil

            Task {
                completion?()
                // Signal change on upload finished, after completion
                try await self.manager.signalEnumerator(for: .workingSet)
                try await self.manager.signalEnumerator(for: uploadFileProviderItem.parentItemIdentifier)
            }
        }

        uploadQueue.resumeAllOperations()
        _ = uploadQueue.saveToRealm(uploadFile, itemIdentifier: uploadFileProviderItem.itemIdentifier, addToQueue: true)
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
