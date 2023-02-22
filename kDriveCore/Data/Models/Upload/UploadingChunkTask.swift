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
import RealmSwift
import InfomaniakDI

/// Tracks the upload of a chunk
final public class UploadingChunkTask: Object {
    
    override public init() {
        // We have to keep it for Realm
    }
    
    convenience init(chunkNumber: Int64, range: DataRange) {
        self.init()
        
        self.chunkNumber = chunkNumber
        self.range = range
    }
    
    @Persisted public var chunk: UploadedChunk?
    @Persisted private var _error: Data?
    
    @Persisted public var chunkNumber: Int64
    @Persisted public var chunkSize: Int64
    @Persisted public var sha256: String?
    
    /// Current upload session token
    @Persisted public var sessionToken: String?
    
    /// Current task identifier
    @Persisted public var taskIdentifier: String?
    
    /// Tracking the session identifier used for the upload task
    @Persisted public var sessionIdentifier: String?
    
    /// Tracking the upload request
    @Persisted public var requestUrl: String?
    
    /// The path to the chunk file on the file system
    @Persisted public var path: String?
    
    @Persisted public var _lowerBound: Int64
    @Persisted public var _upperBound: Int64
    
    @LazyInjectService var fileManager: FileManagerable
    
    /// Returns true if a network request is in progress.
    public var scheduled: Bool {
        requestUrl != nil && requestUrl?.isEmpty == false
    }
    
    public var doneUploading: Bool {
        (chunk != nil) || (error != nil)
    }
    
    /// Precond for starting the upload process
    public var canStartUploading: Bool {
        (doneUploading == false) && (hasLocalChunk == true) && (sessionIdentifier == nil) && (scheduled == false)
    }
    
    /// The chunk is stored locally inside a file, with a path and we have a valid hash of it.
    public var hasLocalChunk: Bool {
        guard let path,
              path.isEmpty == false,
              fileManager.isReadableFile(atPath: path) == true,
              let sha256,
              sha256.isEmpty == false else {
            return false
        }
        return true
    }
    
    public var uploadResult: Result<UploadedChunk, DriveError>? {
        guard let chunk else {
            guard let error else {
                return nil
            }
            return Result.failure(error)
        }
        return Result.success(chunk)
    }
    
    public var range: DataRange {
        get {
            return UInt64(_lowerBound)...UInt64(_upperBound)
        }
        set {
            chunkSize = Int64(newValue.upperBound - newValue.lowerBound) + 1
            _lowerBound = Int64(newValue.lowerBound)
            _upperBound = Int64(newValue.upperBound)
        }
    }
    
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
