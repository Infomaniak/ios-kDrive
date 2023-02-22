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

/// Tracks the upload operation, given a session for a file
final public class UploadingSessionTask: Object {
    @Persisted public var uploadSession: RUploadSession?
    @Persisted public var token: String
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
    
    public var isExpired: Bool {
        return Date() > sessionExpiration
    }
    
    public var fileIdentityHasNotChanged: Bool {
        currentFileIdentity == fileIdentity
    }

    /// Return a string that is expected to change if the file change, without needing to read the whole file
    public var currentFileIdentity: String {
        @InjectService var fileMetadata: FileMetadatable
        let fileUrl = URL(fileURLWithPath: filePath, isDirectory: false)
        let fileCreationDate = fileMetadata.fileCreationDate(url: fileUrl)
        let fileModificationDate = fileMetadata.fileModificationDate(url: fileUrl)
        let fileUniqIdentity = "\(String(describing: fileCreationDate))_\(String(describing: fileModificationDate))"
        return fileUniqIdentity
    }
}