/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import Foundation
import InfomaniakCore
import InfomaniakDI

/// DTO of the `UploadFile` Realm object
public final class UploadFileProviderItem: NSObject, NSFileProviderItem {
    var parentDirectoryId: Int
    var userId: Int
    var driveId: Int
    var sourceUrl: URL
    var conflictOption: ConflictOption
    var shouldRemoveAfterUpload: Bool

    // MARK: Required NSFileProviderItem properties

    public var typeIdentifier: String
    public var capabilities: NSFileProviderItemCapabilities

    public var filename: String {
        sourceUrl.lastPathComponent
    }

    public var itemIdentifier: NSFileProviderItemIdentifier
    public var parentItemIdentifier: NSFileProviderItemIdentifier

    // MARK: optional NSFileProviderItem properties

    public var isUploading: Bool {
        @InjectService var uploadQueue: UploadQueue
        let uploadFile = uploadQueue.getUploadingFile(fileProviderItemIdentifier: itemIdentifier.rawValue)
        return uploadFile != nil
    }

    public var isUploaded = false

    // TODO: Map error form UploadFile.error

    public init(
        uploadFileUUID: String,
        parentDirectoryId: Int,
        userId: Int,
        driveId: Int,
        sourceUrl: URL,
        conflictOption: ConflictOption,
        shouldRemoveAfterUpload: Bool
    ) {
        self.parentDirectoryId = parentDirectoryId
        parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: "\(parentDirectoryId)")
        self.userId = userId
        self.driveId = driveId
        itemIdentifier = NSFileProviderItemIdentifier(rawValue: "\(uploadFileUUID)")
        self.sourceUrl = sourceUrl
        typeIdentifier = sourceUrl.typeIdentifier ?? UTI.item.identifier
        capabilities = .allowsAll
        self.conflictOption = conflictOption
        self.shouldRemoveAfterUpload = shouldRemoveAfterUpload

        super.init()
    }
}

// TODO: Share protocol btwn UploadFileProviderItem / UploadFile
public extension UploadFileProviderItem {
    var toUploadFile: UploadFile {
        UploadFile(
            parentDirectoryId: parentDirectoryId,
            userId: userId,
            driveId: driveId,
            fileProviderItemIdentifier: itemIdentifier.rawValue,
            url: sourceUrl,
            name: filename,
            conflictOption: conflictOption,
            shouldRemoveAfterUpload: shouldRemoveAfterUpload
        )
    }
}
