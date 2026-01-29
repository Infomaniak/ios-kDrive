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

import Alamofire
import Foundation
import InfomaniakCore

// MARK: - Upload APIV2

enum APIUploadParameter: String {
    case driveId = "drive_id"
    case conflict
    case createdAt = "created_at"
    case directoryId = "directory_id"
    case directoryPath = "directory_path"
    case fileId = "file_id"
    case fileName = "file_name"
    case lastModifiedAt = "last_modified_at"
    case totalChunks = "total_chunks"
    case totalSize = "total_size"
    case chunkNumber = "chunk_number"
    case chunkSize = "chunk_size"
    case chunkHash = "chunk_hash"
    case with
}

public extension DriveApiFetcher {
    internal typealias APIParameters = [APIUploadParameter: Encodable?]
    /// Starts a session to upload a file in multiple parts
    ///
    /// https://developer.infomaniak.com/docs/api/post/2/drive/%7Bdrive_id%7D/upload/session/start
    ///
    /// - Parameters:
    ///   - drive: the abstract drive, REQUIRED
    ///   - totalSize: the total size of the file, in Bytes REQUIRED
    ///   - fileName: name of the file
    ///   - conflictResolution: conflict resolution selection
    ///   - totalChunks: the count of chunks the backend should expect
    ///   - lastModifiedAt: override last modified date
    ///   - createdAt: override created at
    ///   - directoryId: The directory destination root of the new file. Must be a directory.
    /// If the identifier is unknown you can use only directory_path.
    /// The identifier 1 is the user root folder.
    /// Required without directory_path
    ///   - directoryPath: The destination path of the new file. If the directory_id is provided the directory path is used as a
    /// relative path, otherwise it will be used as an absolute path. The destination should be a directory.
    /// If the directory path does not exist, folders are created automatically.
    /// The path is a destination path, the file name should not be provided at the end.
    /// Required without directory_id.
    ///   - fileId: File identifier of uploaded file.
    ///
    /// - Returns: an UploadSession struct.
    func startSession(drive: AbstractDrive,
                      totalSize: UInt64,
                      fileName: String,
                      totalChunks: Int,
                      conflictResolution: ConflictOption? = nil,
                      lastModifiedAt: Date? = nil,
                      createdAt: Date? = nil,
                      directoryId: Int? = nil,
                      directoryPath: String? = nil,
                      fileId: Int? = nil) async throws -> UploadSession {
        // Parameter validation
        guard directoryId != nil || directoryPath != nil else {
            throw DriveError.UploadSessionError.invalidDirectoryParameters
        }

        guard !fileName.isEmpty else {
            throw DriveError.UploadSessionError.fileNameIsEmpty
        }

        guard totalChunks < RangeProvider.kDriveConfig.maxTotalChunks,
              totalChunks >= RangeProvider.kDriveConfig.minTotalChunks else {
            throw DriveError.UploadSessionError.chunksNumberOutOfBounds
        }

        // Build parameters
        var apiParameters: APIParameters = [
            .driveId: drive.id,
            .totalSize: totalSize,
            .fileName: fileName,
            .totalChunks: totalChunks,
            .conflict: conflictResolution?.rawValue,
            .directoryId: directoryId,
            .directoryPath: directoryPath,
            .fileId: fileId
        ]

        if let lastModifiedAt {
            let formattedDate = "\(Int64(lastModifiedAt.timeIntervalSince1970))"
            apiParameters[.lastModifiedAt] = formattedDate
        }

        if let createdAt {
            let formattedDate = "\(Int64(createdAt.timeIntervalSince1970))"
            apiParameters[.createdAt] = formattedDate
        }

        let route: Endpoint = .startSession(drive: drive)

        let request = Request(method: .POST,
                              route: route,
                              GETParameters: nil,
                              body: .POSTParameters(apiParameters.toParameters()))

        let result: UploadSession = try await dispatch(request, networkStack: .Alamofire)
        return result
    }

    func getSession(drive: AbstractDrive, sessionToken: AbstractToken) async throws -> UploadLiveSession {
        let route: Endpoint = .getUploadSession(drive: drive, sessionToken: sessionToken)
        let request = Request(method: .GET,
                              route: route,
                              GETParameters: nil,
                              body: .none)

        let result: UploadLiveSession = try await dispatch(request, networkStack: .Alamofire)
        return result
    }

    func cancelSession(drive: AbstractDrive, sessionToken: AbstractToken) async throws -> Bool {
        let route: Endpoint = .cancelSession(drive: drive, sessionToken: sessionToken)
        let request = Request(method: .DELETE,
                              route: route,
                              GETParameters: nil,
                              body: .none)

        let result: Bool = try await dispatch(request, networkStack: .Alamofire)
        return result
    }

    func closeSession(drive: AbstractDrive, sessionToken: AbstractToken) async throws -> UploadedFile {
        let route: Endpoint = .closeSession(drive: drive, sessionToken: sessionToken)
        let request = Request(method: .POST,
                              route: route,
                              GETParameters: nil,
                              body: .none)

        let result: UploadedFile = try await dispatch(request, networkStack: .Alamofire)
        return result
    }

    func appendChunk(drive: AbstractDrive,
                     sessionToken: AbstractToken,
                     chunkNumber: Int,
                     chunk: Data) async throws -> UploadedChunk {
        let chunkSize = chunk.count
        let chunkHash = "sha256:\(chunk.SHA256DigestString)"
        let parameters: APIParameters = [.chunkNumber: chunkNumber,
                                         .chunkSize: chunkSize,
                                         .chunkHash: chunkHash]
        let route: Endpoint = .appendChunk(drive: drive, sessionToken: sessionToken)

        let request = Request(method: .POST,
                              route: route,
                              GETParameters: parameters.toParameters(),
                              body: .requestBody(chunk))

        let result: UploadedChunk = try await dispatch(request, networkStack: .Alamofire)
        return result
    }

    func upload(drive: AbstractDrive,
                sessionToken: AbstractToken,
                chunkNumber: Int,
                chunk: Data) async throws -> UploadedChunk {
        let chunkSize = chunk.count
        let parameters: APIParameters = [.chunkSize: chunkSize]
        let route: Endpoint = .upload(drive: drive)

        let request = Request(method: .POST,
                              route: route,
                              GETParameters: parameters.toParameters(),
                              body: .none)

        let result: UploadedChunk = try await dispatch(request, networkStack: .Alamofire)
        return result
    }

    func directUpload(drive: AbstractDrive,
                      totalSize: UInt64,
                      fileName: String,
                      conflictResolution: ConflictOption? = nil,
                      lastModifiedAt: Date? = nil,
                      createdAt: Date? = nil,
                      directoryId: Int? = nil,
                      directoryPath: String? = nil,
                      fileData: Data) async throws -> File {
        // Parameter validation
        guard directoryId != nil || directoryPath != nil else {
            throw DriveError.UploadSessionError.invalidDirectoryParameters
        }

        guard !fileName.isEmpty else {
            throw DriveError.UploadSessionError.fileNameIsEmpty
        }

        // Build parameters
        var apiParameters: APIParameters = [
            .driveId: drive.id,
            .totalSize: totalSize,
            .fileName: fileName,
            .conflict: conflictResolution?.rawValue,
            .directoryId: directoryId,
            .directoryPath: directoryPath,
            .with: FileWith.chunkUpload.toQueryItem().value
        ]
        if let lastModifiedAt {
            let formattedDate = "\(Int64(lastModifiedAt.timeIntervalSince1970))"
            apiParameters[.lastModifiedAt] = formattedDate
        }

        if let createdAt {
            let formattedDate = "\(Int64(createdAt.timeIntervalSince1970))"
            apiParameters[.createdAt] = formattedDate
        }

        let route: Endpoint = .directUpload(drive: drive)

        let request = Request(method: .POST,
                              route: route,
                              GETParameters: apiParameters.toParameters(),
                              body: .requestBody(fileData))

        let result: File = try await dispatch(request, networkStack: .Alamofire)
        return result
    }
}

extension [APIUploadParameter: Encodable?] {
    func toParameters() -> EncodableParameters {
        var parameters = EncodableParameters()
        for rawParameter in self {
            if let nonNilValue = rawParameter.value {
                parameters[rawParameter.key.rawValue] = nonNilValue
            }
        }
        return parameters
    }
}
