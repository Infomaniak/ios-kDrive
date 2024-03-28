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
public final class UploadSession: EmbeddedObject, Decodable {
    @Persisted public var directoryId: Int64?

    @Persisted public var directoryPath: String?

    /// Not persisted, as File does not belong to the Upload Realm
    public var file: File?

    @Persisted public var fileName: String

    @Persisted public var result: Bool

    @Persisted public var token: String

    @Persisted public var uploadHost: String

    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        directoryId = try container.decodeIfPresent(Int64.self, forKey: .directoryId)
        directoryPath = try container.decodeIfPresent(String.self, forKey: .directoryPath)
        file = try container.decodeIfPresent(File.self, forKey: .file)
        fileName = try container.decode(String.self, forKey: .fileName)
        result = try container.decode(Bool.self, forKey: .result)
        token = try container.decode(String.self, forKey: .token)
        let hostWithScheme = try container.decode(String.self, forKey: .uploadHost)
        uploadHost = hostWithScheme.replacingOccurrences(of: "https://", with: "")
    }

    enum CodingKeys: String, CodingKey {
        case directoryId
        case directoryPath
        case file
        case fileName
        case result
        case token
        case uploadHost = "uploadUrl"
    }
}
