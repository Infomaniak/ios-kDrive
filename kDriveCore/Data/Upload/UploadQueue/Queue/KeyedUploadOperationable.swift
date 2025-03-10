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

import Foundation

// MARK: - OperationsInQueue

/// Something to match a FileId to an Operation, thread safe.
///
/// Not using an actor, as it does not work well with Realm _yet_
final class KeyedUploadOperationable {
    private let queue = DispatchQueue(label: "com.infomaniak.drive.upload-sync")

    /// a FileId to Operation map, bound to `queue` for access
    private var operationsInQueue: [String: UploadOperationable] = [:]

    public func getObject(forKey key: String) -> UploadOperationable? {
        queue.sync {
            self.operationsInQueue[key]
        }
    }

    public func setObject(_ object: UploadOperationable, key: String) {
        queue.sync {
            self.operationsInQueue[key] = object
        }
    }

    public func removeObject(forKey key: String) {
        _ = queue.sync {
            self.operationsInQueue.removeValue(forKey: key)
        }
    }

    public var isEmpty: Bool {
        var empty = true
        queue.sync {
            empty = self.operationsInQueue.isEmpty
        }
        return empty
    }
}
