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

public class SharedFile: Codable {
    public var id: Int = 0
    public var path: String
    public var canUseTag: Bool
    public var users: [DriveUser]
    public var link: ShareLink?
    public var invitations: [Invitation?]
    public var tags: [Tag?]

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case path = "path"
        case canUseTag = "can_use_tag"
        case users = "users"
        case link = "link"
        case invitations = "invitations"
        case tags = "tags"
    }
}

public class ShareLink: Codable {
    public var canEdit: Bool
    public var url: String
    public var permission: String
    public var blockComments: Bool
    public var blockDownloads: Bool
    public var blockInformation: Bool
    public var validUntil: Int?

    enum CodingKeys: String, CodingKey {
        case canEdit = "can_edit"
        case url
        case permission
        case blockComments = "block_comments"
        case blockDownloads = "block_downloads"
        case blockInformation = "block_information"
        case validUntil = "valid_until"
    }
}

public class Invitation: Codable {
    public var avatar: String?
    public var displayName: String?
    public var email: String
    public var id: Int
    public var invitDrive: Bool
    public var invitDriveId: Int?
    public var permission: UserPermission
    public var status: String
    public var userId: Int?

    enum CodingKeys: String, CodingKey {
        case avatar
        case displayName = "display_name"
        case email
        case id
        case invitDrive = "invit_drive"
        case invitDriveId = "invit_drive_id"
        case permission
        case status
        case userId = "user_id"
    }
}


// MARK: - Share with users
public class SharedUsers: Codable {
    public var errors: [String]
    public var valid: SharedUsersValid

    enum CodingKeys: String, CodingKey {
        case errors = "errors"
        case valid = "valid"
    }
}

public class SharedUsersValid: Codable {
    public var invitations: [Invitation]?
    public var users: [DriveUser]?
    public var tags: [Tag]?

    enum CodingKeys: String, CodingKey {
        case invitations = "invitations"
        case users = "users"
        case tags = "tags"
    }
}

public class FileCheckResult: Codable {
    public var userId: Int
    public var isConflict: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isConflict = "is_conflict"
    }
}
