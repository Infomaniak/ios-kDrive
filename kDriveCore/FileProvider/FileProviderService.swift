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

public protocol FileProviderServiceable {
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

    func rightsToCapabilities(_ rights: Rights) -> NSFileProviderItemCapabilities

    func identifier(for itemURL: URL, domain: NSFileProviderDomain?) -> NSFileProviderItemIdentifier?

    func createStorageUrl(identifier: NSFileProviderItemIdentifier, filename: String,
                          domain: NSFileProviderDomain?) -> URL

    func fileProviderError(from error: DriveError) -> NSFileProviderError
}

public struct FileProviderService: FileProviderServiceable {
    public init() {
        // META: keep SonarCloud happy
    }

    public func rightsToCapabilities(_ rights: Rights) -> NSFileProviderItemCapabilities {
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

    public func identifier(for itemURL: URL, domain: NSFileProviderDomain?) -> NSFileProviderItemIdentifier? {
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

    public func createStorageUrl(identifier: NSFileProviderItemIdentifier, filename: String,
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

    public func fileProviderError(from error: DriveError) -> NSFileProviderError {
        switch error {
        case .fileNotFound, .objectNotFound:
            return NSFileProviderError(.noSuchItem)
        case .unknownToken:
            return NSFileProviderError(.notAuthenticated)
        case .quotaExceeded:
            return NSFileProviderError(.insufficientQuota)
        case .destinationAlreadyExists:
            return NSFileProviderError(.filenameCollision)
        default:
            return NSFileProviderError(.serverUnreachable)
        }
    }
}
