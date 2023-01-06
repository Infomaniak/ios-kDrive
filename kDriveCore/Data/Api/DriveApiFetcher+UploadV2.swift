/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

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
import InfomaniakCore
import Alamofire

public extension DriveApiFetcher {
    
    // MARK: Upload V2
    
    /// Conflict resolution options
    enum ConflictResolution: String {
        /// An error is thrown without creating the file/session.
        case throwError = "error"
        /// Rename the new file with an available name (ex. file.txt to file(3).txt).
        case rename
        /// Replace the content of the existing file (create a new version of the file).
        case version
    }
    
    /// The maximun number of chunks supported
    static let APIMaxChunks = 10000
    
    /// You should send at least one chunk
    static let APIMinChunks = 1
    
    /// Starts a session to upload a file in multiple parts
    ///
    /// https://developer.infomaniak.com/docs/api/post/2/drive/%7Bdrive_id%7D/upload/session/start
    ///
    /// - Parameters:
    ///   - drive: the abstract drive
    ///   - fileName: name of the file
    ///   - conflictResolution: conflict resolution selection
    ///   - totalSize: the total size of the file, in Bytes
    ///   - totalChunks: the count of chunks the backend should expect
    ///   - lastModifiedAt: override last modified date
    ///   - createdAt: override created at
    ///   - directoryID: The directory destination root of the new file. Must be a directory.
    /// If the identifier is unknown you can use only directory_path.
    /// The identifier 1 is the user root folder.
    /// Required without directory_path
    ///   - directoryPath: The destination path of the new file. If the directory_id is provided the directory path is used as a relative path, otherwise it will be used as an absolute path. The destination should be a directory.
    /// If the directory path does not exist, folders are created automatically.
    /// The path is a destination path, the file name should not be provided at the end.
    /// Required without directory_id.
    ///   - fileID: File identifier of uploaded file.
    ///
    /// - Returns: Void, the method will return without error in a success
    public func startSession(drive: AbstractDrive,
                             fileName: String,
                             conflictResolution: ConflictResolution,
                             totalSize: Int,
                             totalChunks: Int,
                             lastModifiedAt: String? = nil,
                             createdAt: Date? = nil,
                             directoryID: Int? = nil,
                             directoryPath: String? = nil,
                             fileID: Int? = nil) async throws -> Bool /* Void not encodable, what do you use for a success ? */ {
        // Parameter validation
        guard directoryID != nil || directoryPath != nil else {
            throw DriveError.UploadSession.invalidDirectoryParameters
        }
        
        guard !fileName.isEmpty else {
            throw DriveError.UploadSession.fileNameIsEmpty
        }
        
        guard totalChunks < Self.APIMaxChunks && totalChunks >= Self.APIMinChunks else {
            throw DriveError.UploadSession.chunksNumberOutOfBounds
        }
        
        let parameters: Parameters = [:]
        let request = authenticatedRequest(.startSession(drive: drive), method: .post, parameters: parameters)

        return try await perform(request: request).data
    }
    
    public func getSession(drive: AbstractDrive) async throws -> [Int] {
        return []
    }
    
    public func cancelSession(drive: AbstractDrive) async throws -> [Int] {
        return []
    }
    
    public func closeSession(drive: AbstractDrive) async throws -> [Int] {
        return []
    }
    
    public func appendChunk(drive: AbstractDrive, Session: String) async throws -> [Int] {
        return []
    }
    
}
