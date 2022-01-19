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

public enum EditPermission: String {
    case read, write
}

public class SharedFile: Codable {
    public var users: [DriveUser]
    public var invitations: [Invitation?]
    public var teams: [Team]

    public var shareables: [Shareable] {
        return teams.sorted() + users + invitations.compactMap { $0 }
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

extension Invitation: Shareable {
    public var right: UserPermission? {
        get {
            return permission
        }
        set {
            permission = newValue ?? .read
        }
    }

    public var shareableName: String {
        return displayName ?? email
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
    public var teams: [Team]?
}

public class FileCheckResult: Codable {
    public var userId: Int
    public var isConflict: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isConflict = "is_conflict"
    }
}
