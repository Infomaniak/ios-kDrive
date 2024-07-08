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

public class Comment: Codable {
    public var id: Int
    public var parentId: Int
    public var body: String
    public var isResolved: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var liked: Bool
    public var likesCount: Int
    public var responsesCount: Int
    public var user: DriveUser
    public var responses: [Comment]?
    public var likes: [DriveUser]?
    public var isResponse = false

    enum CodingKeys: String, CodingKey {
        case id
        case parentId
        case body
        case isResolved
        case createdAt
        case updatedAt
        case liked
        case likesCount
        case responsesCount
        case user
        case responses
        case likes
    }
}
