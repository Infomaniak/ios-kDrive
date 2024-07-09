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

/// DTO of the `File` Realm object
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
    public var isUploading = false
    public var isUploaded = true
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

    // MARK: Static

    public static func getFileName(file: File, drive: Drive?) -> String {
        file.name.isEmpty ? "Root" : file.formattedLocalizedName(drive: drive)
    }

    public static func getStorageUrl(file: File, domain: NSFileProviderDomain?) -> URL {
        @InjectService var fileProviderService: FileProviderServiceable
        let identifier = NSFileProviderItemIdentifier(file.id)
        let fileName = getFileName(file: file, drive: nil)
        let storageUrl = fileProviderService.createStorageUrl(identifier: identifier, filename: fileName, domain: domain)
        return storageUrl
    }

    /// Init a `FileProviderItem` DTO
    ///
    /// Prefer using `FileProviderItemProvider` than calling init directly
    init(file: File, parent: NSFileProviderItemIdentifier? = nil, drive: Drive?, domain: NSFileProviderDomain?) {
        Log.fileProvider("FileProviderItem init file:\(file.id)")
        @InjectService var fileProviderService: FileProviderServiceable

        fileId = file.id
        itemIdentifier = NSFileProviderItemIdentifier(file.id)
        filename = Self.getFileName(file: file, drive: drive)
        typeIdentifier = file.typeIdentifier

        let rights = !file.capabilities.isManagedByRealm ? file.capabilities : file.capabilities.freeze()
        capabilities = fileProviderService.rightsToCapabilities(rights)

        // Every file should have a parent, root file parent should not be called
        // If provided a different parent eg. WorkingSet
        parentItemIdentifier = parent ?? NSFileProviderItemIdentifier(file.parent?.id ?? 1)

        isDirectory = file.isDirectory
        if file.isDirectory && file.fullyDownloaded {
            let totalCount = file.children.count
            childItemCount = NSNumber(value: totalCount)
        }

        if let size = file.size {
            documentSize = NSNumber(value: size)
        }

        createdBy = file.createdBy
        isTrashed = file.isTrashed
        creationDate = file.createdAt
        contentModificationDate = file.lastModifiedAt
        var modifiedAtInterval = file.lastModifiedAt.timeIntervalSince1970
        versionIdentifier = Data(bytes: &modifiedAtInterval, count: MemoryLayout.size(ofValue: modifiedAtInterval))
        isMostRecentVersionDownloaded = !file.isLocalVersionOlderThanRemote

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

        storageUrl = Self.getStorageUrl(file: file, domain: domain)
    }

    override public var description: String {
        """
        \(super.description)
        fileId:\(String(describing: fileId))
        itemIdentifier:\(itemIdentifier)
        filename:\(filename)
        typeIdentifier:\(typeIdentifier)
        capabilities:\(capabilities)
        parentItemIdentifier:\(parentItemIdentifier)
        isDirectory:\(isDirectory)
        childItemCount:\(String(describing: childItemCount))
        documentSize:\(String(describing: documentSize))
        createdBy:\(String(describing: createdBy))
        isTrashed:\(isTrashed)
        creationDate:\(String(describing: creationDate))
        contentModificationDate:\(String(describing: contentModificationDate))
        versionIdentifier:\(String(describing: versionIdentifier))
        isMostRecentVersionDownloaded:\(isMostRecentVersionDownloaded)
        isDownloaded:\(isDownloaded)
        isShared:\(isShared)
        ownerNameComponents:\(String(describing: ownerNameComponents))
        storageUrl:\(storageUrl)
        """
    }
}
