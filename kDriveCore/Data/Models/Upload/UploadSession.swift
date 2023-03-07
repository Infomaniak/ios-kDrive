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
import RealmSwift

/// The object returned at the startSession call
public struct UploadSession: Decodable {
    public var directoryId: Int64?
    
    public var directoryPath: String?
    
    public var file: File?
    
    public var fileName: String
    
    public var message: String?
    
    public var result: Bool
    
    public var token: String

    enum CodingKeys: String, CodingKey {
        case directoryId = "directory_id"
        case directoryPath = "directory_path"
        case file
        case fileName = "file_name"
        case message
        case result
        case token
    }
}

// TODO: Fusion UploadSession and RUploadSession
public final class RUploadSession: EmbeddedObject, Decodable {
    @Persisted public var directoryId: Int64?
    
    @Persisted public var directoryPath: String?
    
    @Persisted public var fileName: String
    
    @Persisted public var message: String?
    
    @Persisted public var result: Bool
    
    @Persisted public var token: String
    
    public convenience init(uploadSession: UploadSession) {
        self.init()

        self.fileName = uploadSession.fileName
        self.message = uploadSession.message
        self.result = uploadSession.result
        self.token = uploadSession.token
    }
    
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.directoryId = try container.decodeIfPresent(Int64.self, forKey: .directoryId)
        self.directoryPath = try container.decodeIfPresent(String.self, forKey: .directoryPath)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.result = try container.decode(Bool.self, forKey: .result)
        self.token = try container.decode(String.self, forKey: .token)
    }
    
    enum CodingKeys: String, CodingKey {
        case directoryId = "directory_id"
        case directoryPath = "directory_path"
        case file
        case fileName = "file_name"
        case message
        case result
        case token
    }
}
