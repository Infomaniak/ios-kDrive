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

/// Tracks the upload operation, given a session for a file
final public class UploadingSessionTask: Object {
    @Persisted public var uploadSession: RUploadSession?
    @Persisted public var sessionExpiration: Date
    @Persisted public var chunkTasks: List<UploadingChunkTask>
    
    /// Allows us to make sure the file was not edited while the upload session runs
    @Persisted public var fileIdentity: String
    
    /// The source file path
    @Persisted public var filePath: String

    override public init() {
        // We have to keep it for Realm
    }
    
    public convenience init(uploadSession: RUploadSession,
                            sessionExpiration: Date,
                            chunkTasks: List<UploadingChunkTask>,
                            fileIdentity: String,
                            filePath: String) {
        self.init()
        
        self.uploadSession = uploadSession
        self.sessionExpiration = sessionExpiration
        self.chunkTasks = chunkTasks
        self.fileIdentity = fileIdentity
        self.filePath = filePath
    }
    
    public var isNearlyExpired: Bool {
        let ellevenHours = 60 * 60 * 11
        return Date(timeIntervalSinceNow: TimeInterval(ellevenHours)) > sessionExpiration
    }
    
    public var isExpired: Bool {
        let twelveHours = 60 * 60 * 12
        return Date(timeIntervalSinceNow: TimeInterval(twelveHours)) > sessionExpiration
    }
    
    var ranges: [DataRange] {
        get {
            var ranges = [DataRange]()
            for task in chunkTasks {
                let dataRange: DataRange = task.range
                ranges.append(dataRange)
            }
            return ranges
        }
        set {
            fatalError("Unexpected")
        }
    }
}
