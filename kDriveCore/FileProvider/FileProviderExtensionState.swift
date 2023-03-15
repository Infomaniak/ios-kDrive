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

public protocol FileProviderExtensionStatable {
    func importedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem]

    func unenumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem]

    func deleteAlreadyEnumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier)
        -> [NSFileProviderItemIdentifier]

    var importedDocuments: [NSFileProviderItemIdentifier: FileProviderItem] { get set }

    var workingSet: [NSFileProviderItemIdentifier: FileProviderItem] { get set }
}

public class FileProviderExtensionState: FileProviderExtensionStatable {
    public var importedDocuments = [NSFileProviderItemIdentifier: FileProviderItem]()
    public var workingSet = [NSFileProviderItemIdentifier: FileProviderItem]()

    public func importedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier) -> [FileProviderItem] {
        FileProviderLog("importedDocuments parent:\(parentItemIdentifier.rawValue)")
        return importedDocuments.values.filter { $0.parentItemIdentifier == parentItemIdentifier }
    }

    public func unenumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier)
        -> [FileProviderItem] {
        FileProviderLog("unenumeratedImportedDocuments parent:\(parentItemIdentifier.rawValue)")
        let children = importedDocuments.values
            .filter { $0.parentItemIdentifier == parentItemIdentifier && !$0.alreadyEnumerated }
        children.forEach { $0.alreadyEnumerated = true }
        return children
    }

    public func deleteAlreadyEnumeratedImportedDocuments(forParent parentItemIdentifier: NSFileProviderItemIdentifier)
        -> [NSFileProviderItemIdentifier] {
        FileProviderLog("deleteAlreadyEnumeratedImportedDocuments parent:\(parentItemIdentifier.rawValue)")
        let children = importedDocuments.values
            .filter { $0.parentItemIdentifier == parentItemIdentifier && $0.alreadyEnumerated }
        return children.compactMap { importedDocuments.removeValue(forKey: $0.itemIdentifier)?.itemIdentifier }
    }
}
