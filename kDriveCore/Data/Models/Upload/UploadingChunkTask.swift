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
import InfomaniakDI
import RealmSwift

/// Tracks the upload of a chunk
public final class UploadingChunkTask: EmbeddedObject {
    @LazyInjectService var fileManager: FileManagerable

    override public init() {
        // We have to keep it for Realm
    }

    convenience init(chunkNumber: Int64, range: DataRange) {
        self.init()

        self.chunkNumber = chunkNumber
        self.range = range
    }

    // MARK: - Persisted Properties

    @Persisted public var chunk: UploadedChunk?
    @Persisted private var _error: Data?

    @Persisted public var chunkNumber: Int64
    @Persisted public var chunkSize: Int64
    @Persisted public var sha256: String?

    // TODO: Remove once APIV2 is updated
    /// Current upload session token
    @Persisted public var sessionToken: String?

    /// Current task identifier, uniq within a session
    @Persisted public var taskIdentifier: String?

    /// Tracking the session identifier used for the upload task
    @Persisted public var sessionIdentifier: String?

    /// Tracking the upload request
    @Persisted public var requestUrl: String?

    /// The path to the chunk file on the file system
    @Persisted public var path: String?

    /// The persisted lowerBound of the `DataRange`
    @Persisted public var _lowerBound: Int64

    /// The persisted upperBound of the `DataRange`
    @Persisted public var _upperBound: Int64

    // MARK: - Predicates

    public static let scheduledPredicate = NSPredicate(format: "requestUrl != nil")

    /// A predicate that will allow you to filter only the elements that are done uploading. (regardless of error state)
    public static let doneUploadingPredicate = NSPredicate(format: "chunk != nil OR _error != nil")

    /// A predicate that will allow you to filter only the elements that are not done uploading. (regardless of error state)
    public static let notDoneUploadingPredicate = NSPredicate(format: "chunk = nil AND _error = nil")

    /// A precondition to start uploading, but not all of the checks can be added to the predicate.
    public static let canStartUploadingPreconditionPredicate = NSPredicate(format: "chunk = nil AND _error = nil AND sessionIdentifier = nil AND taskIdentifier = nil AND requestUrl = nil")

    // MARK: - Computed Properties

    /// The chunk is stored locally inside a file, with a path and we have a valid hash of it.
    public var hasLocalChunk: Bool {
        guard let path,
              !path.isEmpty,
              fileManager.isReadableFile(atPath: path),
              let sha256,
              !sha256.isEmpty else {
            return false
        }
        return true
    }

    /// The range of the original file
    public var range: DataRange {
        get {
            return UInt64(_lowerBound) ... UInt64(_upperBound)
        }
        set {
            chunkSize = Int64(newValue.upperBound - newValue.lowerBound) + 1
            _lowerBound = Int64(newValue.lowerBound)
            _upperBound = Int64(newValue.upperBound)
        }
    }

    /// The persisted error, type friendly
    public var error: DriveError? {
        get {
            if let error = _error {
                return DriveError.from(realmData: error)
            } else {
                return nil
            }
        }
        set {
            _error = newValue?.toRealm()
        }
    }
}
