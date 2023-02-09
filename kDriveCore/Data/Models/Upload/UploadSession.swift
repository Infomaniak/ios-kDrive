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
public final class UploadSession: Object, Decodable {
    @Persisted(primaryKey: true) public var directoryID: Int64?
    
    @Persisted public var directoryPath: String?
    
    @Persisted public var file: File?
    
    @Persisted public var fileName: String
    
    @Persisted public var message: String?
    
    @Persisted public var result: String
    
    @Persisted public var token: String
    
    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.directoryID = try container.decodeIfPresent(Int64.self, forKey: .directoryID)
        self.directoryPath = try container.decodeIfPresent(String.self, forKey: .directoryPath)
        self.file = try container.decodeIfPresent(File.self, forKey: .file)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.result = try container.decode(String.self, forKey: .result)
        self.token = try container.decode(String.self, forKey: .token)
    }
    
    enum CodingKeys: String, CodingKey {
        case directoryID = "directory_id"
        case directoryPath = "directory_path"
        case file
        case fileName = "file_name"
        case message
        case result
        case token
    }
}
