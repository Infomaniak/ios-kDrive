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

public struct FileAccessSettings: Encodable {
    /// Language of the request email to be sent.
    public var lang: String
    /// Message for the invitation.
    public var message: String?
    /// Access file right to set.
    public var right: UserPermission
    public var emails: [String]?
    public var teamIds: [Int]?
    public var userIds: [Int]?

    public init(message: String? = nil, right: UserPermission, emails: [String]? = nil, teamIds: [Int]? = nil, userIds: [Int]? = nil) {
        var lang = "en"
        if let languageCode = Locale.current.languageCode, ["fr", "de", "it", "en", "es"].contains(languageCode) {
            lang = languageCode
        }
        self.lang = lang
        self.message = message
        self.right = right
        self.emails = emails
        self.teamIds = teamIds
        self.userIds = userIds
    }
}

public class FileAccess: Codable {
    public var users: [UserFileAccess]
    public var invitations: [ExternInvitationFileAccess]
    public var teams: [TeamFileAccess]

    public var shareables: [Shareable] {
        return teams.sorted() + users + invitations
    }
}

public class UserFileAccess: Codable, Shareable {
    public var id: Int
    public var name: String
    public var right: UserPermission
    public var email: String
    public var status: UserFileAccessStatus
    public var user: DriveUser

    public var userId: Int? {
        return id
    }
}

public enum UserFileAccessStatus: String, Codable {
    case active, deletedKept = "deleted_kept", deletedRemoved = "deleted_removed", deletedTransferred = "deleted_transferred", locked, pending
}

public class TeamFileAccess: Codable, Shareable {
    public var id: Int
    public var name: String
    public var right: UserPermission
    public var status: FileAccessStatus

    public var isAllUsers: Bool {
        return id == Team.allUsersId
    }

    public var userId: Int? {
        return nil
    }
}

extension TeamFileAccess: Comparable {
    public static func == (lhs: TeamFileAccess, rhs: TeamFileAccess) -> Bool {
        return lhs.id == rhs.id
    }

    public static func < (lhs: TeamFileAccess, rhs: TeamFileAccess) -> Bool {
        return lhs.isAllUsers || lhs.name.lowercased() < rhs.name.lowercased()
    }
}

public class ExternInvitationFileAccess: Codable, Shareable {
    public var id: Int
    public var name: String
    public var right: UserPermission
    public var status: FileAccessStatus
    public var email: String
    public var user: DriveUser?
    public var invitationDriveId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case right
        case status
        case email
        case user
        case invitationDriveId = "invitation_drive_id"
    }

    public var userId: Int? {
        return user?.id
    }
}

public enum FileAccessStatus: String, Codable {
    case accepted, cancelled, expired, pending, rejected
}

// MARK: - Share with users

public class AccessResponse: Codable {
    public var emails: [FeedbackAccessResource<String, ExternInvitationFileAccess>]
    public var users: [FeedbackAccessResource<Int, UserFileAccess>]
    public var teams: [FeedbackAccessResource<Int, TeamFileAccess>]
}

public class FeedbackAccessResource<IdType: Codable, AccessType: Codable>: Codable {
    public var id: IdType
    public var result: Bool
    public var access: AccessType
    public var message: String
}

public class CheckChangeAccessFeedbackResource: Codable {
    public var userId: Int
    public var currentRight: String
    public var needChange: Bool
    public var message: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case currentRight = "current_right"
        case needChange = "need_change"
        case message
    }
}
