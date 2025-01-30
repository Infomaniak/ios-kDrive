/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

public struct PublicShareMetadata: Decodable {
    public let url: URL
    public let fileId: Int
    public let right: String

    public let validUntil: TimeInterval?
    public let capabilities: Rights

    public let createdBy: TimeInterval
    public let createdAt: TimeInterval
    public let updatedAt: TimeInterval
    public let accessBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case url
        case fileId
        case right
        case validUntil
        case capabilities
        case createdBy
        case createdAt
        case updatedAt
        case accessBlocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        url = try container.decode(URL.self, forKey: .url)
        fileId = try container.decode(Int.self, forKey: .fileId)
        right = try container.decode(String.self, forKey: .right)

        validUntil = try container.decodeIfPresent(TimeInterval.self, forKey: .validUntil)
        capabilities = try container.decode(Rights.self, forKey: .capabilities)

        createdBy = try container.decode(TimeInterval.self, forKey: .createdBy)
        createdAt = try container.decode(TimeInterval.self, forKey: .createdAt)
        updatedAt = try container.decode(TimeInterval.self, forKey: .updatedAt)

        accessBlocked = try container.decode(Bool.self, forKey: .accessBlocked)
    }
}
