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

public extension NSFileProviderItemIdentifier {
    init(_ directoryId: Int) {
        if directoryId == DriveFileManager.constants.rootID {
            self.init(NSFileProviderItemIdentifier.rootContainer.rawValue)
        } else {
            self.init("\(directoryId)")
        }
    }

    func toFileId() -> Int? {
        if self == .rootContainer {
            return DriveFileManager.constants.rootID
        } else {
            let fileId = Int(rawValue)
            return fileId
        }
    }
}

public final class FileProviderItem: NSObject, NSFileProviderItem {
    // MARK: Private properties

    private var fileId: Int?
    private var createdBy: Int?
    private var isDirectory: Bool

    // MARK: Required properties

    public var itemIdentifier: NSFileProviderItemIdentifier
    public var filename: String
    public var typeIdentifier: String
    public var capabilities: NSFileProviderItemCapabilities
    public var parentItemIdentifier: NSFileProviderItemIdentifier

    // MARK: Optional properties

    public var childItemCount: NSNumber?
    public var documentSize: NSNumber?
    public var isTrashed: Bool
    public var creationDate: Date?
    public var contentModificationDate: Date?
    public var versionIdentifier: Data?
    public var isMostRecentVersionDownloaded: Bool
    public var isUploading: Bool
    public var isUploaded: Bool
    public var uploadingError: Error?
    public var isDownloading: Bool {
        guard !isDirectory else {
            return false
        }

        guard let fileId else {
            return false
        }

        return DownloadQueue.instance.hasOperation(for: fileId)
    }

    public var isDownloaded: Bool
    public var downloadingError: Error?
    public var isShared: Bool
    public var isSharedByCurrentUser: Bool {
        guard isShared else {
            return false
        }

        guard let createdBy else {
            return false
        }

        @InjectService var accountManager: AccountManageable
        return createdBy == accountManager.currentUserId
    }

    public var ownerNameComponents: PersonNameComponents?
    public var favoriteRank: NSNumber?

    // MARK: Custom properties

    public var storageUrl: URL
    public var alreadyEnumerated = false

    public init(file: File, domain: NSFileProviderDomain?) {
        Log.fileProvider("FileProviderItem init file:\(file.id)")

        fileId = file.id
        itemIdentifier = NSFileProviderItemIdentifier(file.id)
        filename = file.name.isEmpty ? "Root" : file.name
        typeIdentifier = file.typeIdentifier

        let rights = !file.capabilities.isManagedByRealm ? file.capabilities : file.capabilities.freeze()
        capabilities = FileProviderItem.rightsToCapabilities(rights)

        // Every file should have a parent, root file parent should not be called
        parentItemIdentifier = NSFileProviderItemIdentifier(file.parent?.id ?? 1)

        isDirectory = file.isDirectory
        childItemCount = file.isDirectory ? NSNumber(value: file.children.count) : nil
        if let size = file.size {
            documentSize = NSNumber(value: size)
        }

        createdBy = file.createdBy
        isTrashed = file.isTrashed
        creationDate = file.createdAt
        contentModificationDate = file.lastModifiedAt
        versionIdentifier = Data(bytes: &contentModificationDate, count: MemoryLayout.size(ofValue: contentModificationDate))
        isMostRecentVersionDownloaded = !file.isLocalVersionOlderThanRemote

        // TODO: Lookup upload queue form id, for now fake it
        isUploading = false
        isUploaded = true

        if file.isDirectory {
            // TODO: Enable and allow to download all folder content locally
            isDownloaded = true
        } else if DownloadQueue.instance.hasOperation(for: file.id) {
            isDownloaded = false
        } else {
            isDownloaded = file.isDownloaded
        }

        isShared = file.users.count > 1

        if let user = file.creator {
            var nameComponents = PersonNameComponents()
            nameComponents.nickname = user.displayName
            ownerNameComponents = nameComponents
        }

        let itemStorageUrl = FileProviderItem.createStorageUrl(identifier: itemIdentifier, filename: filename, domain: domain)
        storageUrl = itemStorageUrl
    }

    public init(importedFileUrl: URL, identifier: NSFileProviderItemIdentifier, parentIdentifier: NSFileProviderItemIdentifier) {
        Log.fileProvider("FileProviderItem init importedFileUrl:\(importedFileUrl)")

        fileId = identifier.toFileId()
        isDirectory = false

        itemIdentifier = identifier
        filename = importedFileUrl.lastPathComponent
        typeIdentifier = importedFileUrl.typeIdentifier ?? UTI.item.identifier
        capabilities = .allowsAll
        parentItemIdentifier = parentIdentifier

        let resourceValues = try? importedFileUrl
            .resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .totalFileSizeKey])
        if let totalSize = resourceValues?.totalFileSize {
            documentSize = NSNumber(value: totalSize)
        }
        creationDate = resourceValues?.creationDate
        contentModificationDate = resourceValues?.contentModificationDate
        versionIdentifier = Data(bytes: &contentModificationDate, count: MemoryLayout.size(ofValue: contentModificationDate))
        isUploading = true
        isUploaded = false
        isDownloaded = false
        isMostRecentVersionDownloaded = false
        isShared = false
        isTrashed = false
        storageUrl = importedFileUrl
    }

    public func setUploadingError(_ error: DriveError) {
        Log.fileProvider("FileProviderItem setUploadingError:\(error)")
        switch error {
        case .fileNotFound, .objectNotFound:
            uploadingError = NSFileProviderError(.noSuchItem)
        case .unknownToken:
            uploadingError = NSFileProviderError(.notAuthenticated)
        case .quotaExceeded:
            uploadingError = NSFileProviderError(.insufficientQuota)
        case .destinationAlreadyExists:
            uploadingError = NSFileProviderError(.filenameCollision)
        default:
            uploadingError = NSFileProviderError(.serverUnreachable)
        }
    }

    /*
      (write)              .allowsWriting -> rights.write
      (read properties)    .allowsReading -> rights.read
      (rename)             .allowsRenaming -> rights.rename
      (trash)              .allowsTrashing -> rights.delete
      (delete)             .allowsDeleting -> ~= rights.delete
      (move file/folder)   .allowsReparenting -> rights.move
      (add file to folder) .allowsAddingSubItems -> rights.moveInto
      (list folder files)  .allowsContentEnumerating -> rights.read
     */
    private class func rightsToCapabilities(_ rights: Rights) -> NSFileProviderItemCapabilities {
        var capabilities: NSFileProviderItemCapabilities = []
        if rights.canWrite {
            capabilities.insert(.allowsWriting)
        }
        if rights.canRead {
            capabilities.insert(.allowsReading)
        }
        if rights.canRename {
            capabilities.insert(.allowsRenaming)
        }
        if rights.canDelete {
            capabilities.insert(.allowsDeleting)
            capabilities.insert(.allowsTrashing)
        }
        if rights.canMove {
            capabilities.insert(.allowsReparenting)
        }
        if rights.canMoveInto || rights.canCreateDirectory || rights.canCreateFile || rights.canUpload {
            capabilities.insert(.allowsAddingSubItems)
        }
        if rights.canShow {
            capabilities.insert(.allowsContentEnumerating)
        }
        return capabilities
    }

    public class func identifier(for itemURL: URL, domain: NSFileProviderDomain?) -> NSFileProviderItemIdentifier? {
        let rootStorageURL: URL
        if let domain {
            rootStorageURL = NSFileProviderManager(for: domain)!.documentStorageURL
                .appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true)
        } else {
            rootStorageURL = NSFileProviderManager.default.documentStorageURL
        }
        if itemURL == rootStorageURL {
            return .rootContainer
        }
        let identifier = itemURL.deletingLastPathComponent().lastPathComponent
        return NSFileProviderItemIdentifier(identifier)
    }

    public class func createStorageUrl(identifier: NSFileProviderItemIdentifier, filename: String,
                                       domain: NSFileProviderDomain?) -> URL {
        let rootStorageURL: URL
        if let domain {
            rootStorageURL = NSFileProviderManager(for: domain)!.documentStorageURL
                .appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true)
        } else {
            rootStorageURL = NSFileProviderManager.default.documentStorageURL
        }
        if identifier == .rootContainer {
            return rootStorageURL
        }

        let itemFolderURL = rootStorageURL.appendingPathComponent(identifier.rawValue)
        if !FileManager.default.fileExists(atPath: itemFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: itemFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error)
            }
        }
        return itemFolderURL.appendingPathComponent(filename)
    }
}
