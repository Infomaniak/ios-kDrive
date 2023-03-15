/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import Foundation

/// Something to maintain a coherent placeholder file datasource for Files.app while we upload and fetch a real File entity.
///
/// Concrete implementation `FileProviderExtensionAdditionalState` is ThreadSafe
public protocol FileProviderExtensionAdditionalStatable {
    func importedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem]

    func deleteAlreadyEnumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier)
        -> [NSFileProviderItemIdentifier]

    // MARK: CRUD

    /// Get a File placeholder in an arbitrary folder
    func getImportedDocument(forKey key: NSFileProviderItemIdentifier) -> FileProviderItem?

    /// Set a File placeholder in an arbitrary folder
    func setImportedDocument(_ item: FileProviderItem, forKey key: NSFileProviderItemIdentifier)

    /// Get a File placeholder in the `Recent Files` folder
    func getWorkingDocument(forKey key: NSFileProviderItemIdentifier) -> FileProviderItem?

    /// Get Files placeholder in the `Recent Files` folder
    func getWorkingDocumentValues() -> [FileProviderItem]

    /// Set a File placeholder in the `Recent Files` folder
    func setWorkingDocument(_ item: FileProviderItem, forKey key: NSFileProviderItemIdentifier)

    /// Remove a File placeholder in the `Recent Files` folder
    func removeWorkingDocument(forKey key: NSFileProviderItemIdentifier)
}

public final class FileProviderExtensionAdditionalState: FileProviderExtensionAdditionalStatable {
    /// Any file upload in progress
    private var importedDocuments = [NSFileProviderItemIdentifier: FileProviderItem]()

    /// Recent Files
    private var workingDocuments = [NSFileProviderItemIdentifier: FileProviderItem]()

    /// A serial queue to lock access to ivars.
    let queue = DispatchQueue(label: "com.infomaniak.fileProviderExtensionState.sync", qos: .default)

    public func importedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem] {
        FileProviderLog("importedDocuments parent:\(parentItemIdentifier.rawValue)")
        var documents = [FileProviderItem]()
        queue.sync {
            documents = importedDocuments.values.filter { $0.parentItemIdentifier == parentItemIdentifier }
        }
        return documents
    }

    public func deleteAlreadyEnumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier)
        -> [NSFileProviderItemIdentifier] {
        FileProviderLog("deleteAlreadyEnumeratedImportedDocuments parent:\(parentItemIdentifier.rawValue)")
        var identifiers = [NSFileProviderItemIdentifier]()
        queue.sync {
            let children = importedDocuments.values
                .filter { $0.parentItemIdentifier == parentItemIdentifier && $0.alreadyEnumerated }
            identifiers = children.compactMap { importedDocuments.removeValue(forKey: $0.itemIdentifier)?.itemIdentifier }
        }

        return identifiers
    }

    // MARK: importedDocuments

    public func setImportedDocument(_ item: FileProviderItem, forKey key: NSFileProviderItemIdentifier) {
        FileProviderLog("setImportedDocument key:\(key.rawValue)")
        queue.sync {
            importedDocuments[key] = item
        }
    }

    public func getImportedDocument(forKey key: NSFileProviderItemIdentifier) -> FileProviderItem? {
        FileProviderLog("getImportedDocument key:\(key.rawValue)")
        var item: FileProviderItem?
        queue.sync {
            item = importedDocuments[key]
        }
        return item
    }

    // MARK: workingDocuments

    public func getWorkingDocument(forKey key: NSFileProviderItemIdentifier) -> FileProviderItem? {
        FileProviderLog("getWorkingDocument key:\(key.rawValue)")
        var value: FileProviderItem?
        queue.sync {
            value = workingDocuments[key]
        }
        return value
    }

    public func getWorkingDocumentValues() -> [FileProviderItem] {
        FileProviderLog("getWorkingDocumentValues")
        var values = [FileProviderItem]()
        queue.sync {
            values = [FileProviderItem](workingDocuments.values)
        }
        return values
    }

    public func setWorkingDocument(_ item: FileProviderItem, forKey key: NSFileProviderItemIdentifier) {
        FileProviderLog("setWorkingDocument key:\(key.rawValue)")
        queue.sync {
            workingDocuments[key] = item
        }
    }

    public func removeWorkingDocument(forKey key: NSFileProviderItemIdentifier) {
        FileProviderLog("removeWorkingDocument key:\(key.rawValue)")
        queue.sync {
            workingDocuments.removeValue(forKey: key)
        }
    }
}
