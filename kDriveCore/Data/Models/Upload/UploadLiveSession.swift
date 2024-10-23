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

/// The object returned at the getSession call
public struct UploadLiveSession: Decodable {
    var expectedChunks: UInt64
    var receivedChunks: UInt64
    var uploadingChunks: UInt64
    var failedChunks: UInt64
    var expectedSize: UInt64
    var uploadedSize: UInt64
    var chunks: [UploadedLiveChunk]
}

enum UploadedLiveChunkState: String, Decodable {
    case error
    case ok
    case uploading
}

public struct UploadedLiveChunk: Decodable {
    var number: Int64
    var status: UploadedLiveChunkState
    var createdAt: Date
    var size: Int64
    var chunkHash: String

    enum CodingKeys: String, CodingKey {
        case number
        case status
        case createdAt
        case size
        case chunkHash = "hash"
    }

    public var isValidUpload: Bool {
        return status == .ok
    }

    public func toRealmObject() -> UploadedChunk {
        let chunk = UploadedChunk()
        chunk.number = number
        chunk.status = status.rawValue
        chunk.createdAt = createdAt
        chunk.size = size
        chunk.chunkHash = chunkHash
        return chunk
    }
}
