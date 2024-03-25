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
import InfomaniakDI

/// Something to access and mutate the Working set
public protocol FileProviderWorkingSetServiceable {
    // MARK: CRUD

    /// Get a File placeholder in the `Recent Files` folder
    func getWorkingDocument(forKey key: NSFileProviderItemIdentifier) -> FileProviderItem?

    /// Get Files placeholder in the `Recent Files` folder
    func getWorkingDocumentValues() -> [FileProviderItem]

    /// Set a File placeholder in the `Recent Files` folder
    func setWorkingDocument(_ item: FileProviderItem, forKey key: NSFileProviderItemIdentifier)

    /// Remove a File placeholder in the `Recent Files` folder
    func removeWorkingDocument(forKey key: NSFileProviderItemIdentifier)
}

public final class FileProviderWorkingSetService: FileProviderWorkingSetServiceable {
    /// Recent Files
//    private var workingDocuments = [NSFileProviderItemIdentifier: FileProviderItem]()

    /// A serial queue to lock access to ivars.
    let queue = DispatchQueue(
        label: "com.infomaniak.fileProviderExtensionState.sync",
        qos: .default,
        autoreleaseFrequency: .workItem
    )

    let workingSetDriveFileManager: DriveFileManager

    init?(driveId: Int, userId: Int) {
        @InjectService var accountManager: AccountManageable
        guard let workingSetFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId)?
            .instanceWith(context: .fileProviderWorkingSet) else {
            Log.fileProvider("FileProviderWorkingSetService unable to init", level: .error)
            return nil
        }

        workingSetDriveFileManager = workingSetFileManager
    }

    // MARK: workingDocuments

    public func getWorkingDocument(forKey key: NSFileProviderItemIdentifier) -> FileProviderItem? {
        Log.fileProvider("getWorkingDocument key:\(key.rawValue)")
        var value: FileProviderItem?
        queue.sync {
//            value = workingDocuments[key]
        }
        return value
    }

    public func getWorkingDocumentValues() -> [FileProviderItem] {
        Log.fileProvider("getWorkingDocumentValues")
        var values = [FileProviderItem]()
        queue.sync {
//            values = [FileProviderItem](workingDocuments.values)
        }
        return values
    }

    public func setWorkingDocument(_ item: FileProviderItem, forKey key: NSFileProviderItemIdentifier) {
        Log.fileProvider("setWorkingDocument key:\(key.rawValue)")
        queue.sync {
//            workingDocuments[key] = item
        }
    }

    public func removeWorkingDocument(forKey key: NSFileProviderItemIdentifier) {
        Log.fileProvider("removeWorkingDocument key:\(key.rawValue)")
        queue.sync {
//            workingDocuments.removeValue(forKey: key)
        }
    }
}
