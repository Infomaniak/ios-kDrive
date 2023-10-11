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

public final class UploadedChunk: Object, Decodable {
    @Persisted var number: Int64
    @Persisted var status: String
    @Persisted var createdAt: Date
    @Persisted var size: Int64
    @Persisted var chunkHash: String

    public required convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int64.self, forKey: .number)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        size = try container.decode(Int64.self, forKey: .size)
        chunkHash = try container.decode(String.self, forKey: .chunkHash)
    }

    enum CodingKeys: String, CodingKey {
        case number
        case status
        case createdAt = "created_at"
        case size
        case chunkHash = "hash"
    }

    public var isValidUpload: Bool {
        return status == "ok"
    }
}
