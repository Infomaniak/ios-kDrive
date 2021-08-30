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

public class SharedFile: NSObject, NSCoding, Codable {
    public var id: Int = 0
    public var path: String
    public var canUseTeam: Bool
    public var users: [DriveUser]
    public var link: ShareLink?
    public var invitations: [Invitation?]
    public var teams: [Team]

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case canUseTeam = "can_use_team"
        case users
        case link
        case invitations
        case teams
    }

    public func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "Id")
        coder.encode(path, forKey: "Path")
        coder.encode(canUseTeam, forKey: "CanUseTeam")
        coder.encode(users.map(\.id), forKey: "Users")
        coder.encode(link, forKey: "Link")
        // coder.encode(invitations, forKey: "Invitations")
        coder.encode(teams, forKey: "Teams")
    }

    public required init?(coder: NSCoder) {
        guard let path = coder.decodeObject(forKey: "Path") as? String,
              let users = coder.decodeObject(forKey: "Users") as? [Int],
              // let invitations = coder.decodeObject(forKey: "Invitations") as? [Invitation?],
              let teams = coder.decodeObject(forKey: "Teams") as? [Team] else {
            return nil
        }
        self.id = coder.decodeInteger(forKey: "Id")
        self.path = path
        self.canUseTeam = coder.decodeBool(forKey: "CanUseTeam")
        let realm = DriveInfosManager.instance.getRealm()
        self.users = users.compactMap { DriveInfosManager.instance.getUser(id: $0, using: realm) }
        self.link = coder.decodeObject(forKey: "Link") as? ShareLink
        self.invitations = []
        self.teams = teams
    }
}

public class ShareLink: NSObject, NSCoding, Codable {
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

    public func encode(with coder: NSCoder) {
        coder.encode(canEdit, forKey: "CanEdit")
        coder.encode(url, forKey: "URL")
        coder.encode(permission, forKey: "Permission")
        coder.encode(blockComments, forKey: "BlockComments")
        coder.encode(blockDownloads, forKey: "BlockDownloads")
        coder.encode(blockInformation, forKey: "BlockInformation")
        coder.encode(validUntil, forKey: "ValidUntil")
    }

    public required init?(coder: NSCoder) {
        guard let url = coder.decodeObject(forKey: "URL") as? String,
              let permission = coder.decodeObject(forKey: "Permission") as? String else {
            return nil
        }
        self.canEdit = coder.decodeBool(forKey: "CanEdit")
        self.url = url
        self.permission = permission
        self.blockComments = coder.decodeBool(forKey: "BlockComments")
        self.blockDownloads = coder.decodeBool(forKey: "BlockDownloads")
        self.blockInformation = coder.decodeBool(forKey: "BlockInformation")
        self.validUntil = coder.decodeObject(forKey: "ValidUntil") as? Int
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
}

public class SharedUsersValid: Codable {
    public var invitations: [Invitation]?
    public var users: [DriveUser]?
    public var tags: [Tag]?
}

public class FileCheckResult: Codable {
    public var userId: Int
    public var isConflict: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isConflict = "is_conflict"
    }
}
