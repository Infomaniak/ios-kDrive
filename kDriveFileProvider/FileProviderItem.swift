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
import kDriveCore

extension NSFileProviderItemIdentifier {
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
            return Int(self.rawValue)
        }
    }
}


class FileProviderItem: NSObject, NSFileProviderItem {

    // Required properties

    var itemIdentifier: NSFileProviderItemIdentifier
    var filename: String
    var typeIdentifier: String
    var capabilities: NSFileProviderItemCapabilities
    var parentItemIdentifier: NSFileProviderItemIdentifier

    // Optional properties

    var childItemCount: NSNumber?
    var documentSize: NSNumber?
    var isTrashed = false
    var creationDate: Date?
    var contentModificationDate: Date?
    var versionIdentifier: Data?
    var isMostRecentVersionDownloaded = true
    var isUploading = false
    var isUploaded = true
    var uploadingError: Error?
    var isDownloading = false
    var isDownloaded = true
    var downloadingError: Error?
    var isShared = false
    var isSharedByCurrentUser = false
    var ownerNameComponents: PersonNameComponents?
    var favoriteRank: NSNumber?

    // Custom properties

    var storageUrl: URL
    var alreadyEnumerated = false

    init(file: File, domain: NSFileProviderDomain?) {
        self.itemIdentifier = NSFileProviderItemIdentifier(file.id)
        self.filename = file.name
        self.typeIdentifier = file.typeIdentifier.identifier
        if let rights = file.rights {
            let rights = rights.realm == nil ? rights : rights.freeze()
            self.capabilities = FileProviderItem.rightsToCapabilities(rights)
        } else {
            self.capabilities = [.allowsContentEnumerating, .allowsReading]
        }
        //Every file should have a parent, root file parent should not be called
        self.parentItemIdentifier = NSFileProviderItemIdentifier(file.parent?.id ?? 1)
        let tmpChildren = FileProviderExtensionState.shared.importedDocuments(forParent: itemIdentifier)
        self.childItemCount = file.isDirectory ? NSNumber(value: file.children.count + tmpChildren.count) : nil
        self.documentSize = file.size == 0 ? nil : NSNumber(value: file.size)
        self.isTrashed = file.isTrashed
        self.creationDate = file.fileCreatedAtDate ?? file.createdAtDate
        self.contentModificationDate = file.lastModifiedAt == 0 ? nil : file.lastModifiedDate
        self.versionIdentifier = Data(bytes: &contentModificationDate, count: MemoryLayout.size(ofValue: contentModificationDate))
        self.isMostRecentVersionDownloaded = !file.isLocalVersionOlderThanRemote()
        let storageUrl = FileProviderItem.createStorageUrl(identifier: itemIdentifier, filename: filename, domain: domain)
        if DownloadQueue.instance.operationsInQueue[file.id] != nil {
            self.isDownloading = true
            self.isDownloaded = false
        } else {
            self.isDownloading = false
            self.isDownloaded = FileManager.default.fileExists(atPath: storageUrl.path)
        }
        if file.visibility == .isShared {
            self.isShared = true
            self.isSharedByCurrentUser = file.createdBy == AccountManager.instance.currentUserId
        } else {
            self.isShared = false
            self.isSharedByCurrentUser = false
        }
        if let user = DriveInfosManager.instance.getUser(id: file.createdBy) {
            var ownerNameComponents = PersonNameComponents()
            ownerNameComponents.nickname = user.displayName
            self.ownerNameComponents = ownerNameComponents
        }
        self.storageUrl = storageUrl
    }

    init(importedFileUrl: URL, identifier: NSFileProviderItemIdentifier, parentIdentifier: NSFileProviderItemIdentifier) {
        let resourceValues = try? importedFileUrl.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey, .totalFileSizeKey])
        self.itemIdentifier = identifier
        self.filename = importedFileUrl.lastPathComponent
        self.typeIdentifier = (importedFileUrl.typeIdentifier ?? .item).identifier
        self.capabilities = .allowsAll
        self.parentItemIdentifier = parentIdentifier
        if let totalSize = resourceValues?.totalFileSize {
            self.documentSize = NSNumber(value: totalSize)
        }
        self.creationDate = resourceValues?.creationDate
        self.contentModificationDate = resourceValues?.contentModificationDate
        self.versionIdentifier = Data(bytes: &contentModificationDate, count: MemoryLayout.size(ofValue: contentModificationDate))
        self.isUploading = true
        self.isUploaded = false
        self.storageUrl = importedFileUrl
    }

    func setUploadingError(_ error: DriveError) {
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
        if rights.write.value ?? false {
            capabilities.insert(.allowsWriting)
        }
        if rights.read.value ?? false {
            capabilities.insert(.allowsReading)
        }
        if rights.rename.value ?? false {
            capabilities.insert(.allowsRenaming)
        }
        if rights.delete.value ?? false {
            capabilities.insert(.allowsDeleting)
            capabilities.insert(.allowsTrashing)
        }
        if rights.move.value ?? false {
            capabilities.insert(.allowsReparenting)
        }
        if (rights.moveInto.value ?? false) || (rights.createNewFolder.value ?? false) || (rights.createNewFile.value ?? false) || (rights.uploadNewFile.value ?? false) {
            capabilities.insert(.allowsAddingSubItems)
        }
        if rights.show.value ?? false {
            capabilities.insert(.allowsContentEnumerating)
        }
        return capabilities
    }

    class func identifier(for itemURL: URL, domain: NSFileProviderDomain?) -> NSFileProviderItemIdentifier? {
        let rootStorageURL: URL
        if let domain = domain {
            rootStorageURL = NSFileProviderManager.default.documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true)
        } else {
            rootStorageURL = NSFileProviderManager.default.documentStorageURL
        }
        if itemURL == rootStorageURL {
            return .rootContainer
        }
        let identifier = itemURL.deletingLastPathComponent().lastPathComponent
        return NSFileProviderItemIdentifier(identifier)
    }

    class func createStorageUrl(identifier: NSFileProviderItemIdentifier, filename: String, domain: NSFileProviderDomain?) -> URL {
        let rootStorageURL: URL
        if let domain = domain {
            rootStorageURL = NSFileProviderManager.default.documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage, isDirectory: true)
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
            }
            catch let error {
                print(error)
            }
        }
        return itemFolderURL.appendingPathComponent(filename)
    }

}
