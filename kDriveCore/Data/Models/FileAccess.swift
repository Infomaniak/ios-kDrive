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

import InfomaniakDI
import kDriveResources
import UIKit

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

    private let allowedLanguageCodes = ["fr", "de", "it", "en", "es"]

    public init(
        message: String? = nil,
        right: UserPermission,
        emails: [String]? = nil,
        teamIds: [Int]? = nil,
        userIds: [Int]? = nil
    ) {
        if let languageCode = Locale.current.languageCode, allowedLanguageCodes.contains(languageCode) {
            lang = languageCode
        } else {
            lang = "en"
        }
        self.message = message
        self.right = right
        self.emails = emails
        self.teamIds = teamIds
        self.userIds = userIds
    }

    private enum CodingKeys: String, CodingKey {
        case lang, message, right, emails, teamIds, userIds
    }
}

public protocol FileAccessElement: Codable {
    var id: Int { get }
    var name: String { get }
    var right: UserPermission { get set }
    var color: Int? { get }
    var user: DriveUser? { get }

    var shareable: Shareable? { get }
    var icon: UIImage { get async }
}

public class FileAccess: Codable {
    public var users: [UserFileAccess]
    public var invitations: [ExternInvitationFileAccess]
    public var teams: [TeamFileAccess]

    public var elements: [FileAccessElement] {
        return teams.sorted() + users + invitations
    }
}

public class UserFileAccess: FileAccessElement {
    public var id: Int
    public var name: String
    public var right: UserPermission
    public var color: Int?
    public var status: UserFileAccessStatus
    public var email: String
    public var user: DriveUser?
    public var role: DriveUserRole?

    public var shareable: Shareable? {
        return user
    }

    public var icon: UIImage {
        get async {
            if let user {
                return await withCheckedContinuation { continuation in
                    user.getAvatar { image in
                        continuation.resume(returning: image)
                    }
                }
            } else {
                return KDriveResourcesAsset.placeholderAvatar.image
            }
        }
    }
}

public enum UserFileAccessStatus: String, Codable {
    case active, deletedKept = "deleted_kept", deletedRemoved = "deleted_removed", deletedTransferred = "deleted_transferred",
         locked, pending
}

public class TeamFileAccess: FileAccessElement {
    public var id: Int
    public var name: String
    public var right: UserPermission
    public var color: Int?
    public var status: FileAccessStatus

    public var user: DriveUser? {
        return nil
    }

    public var isAllUsers: Bool {
        return id == Team.allUsersId
    }

    public var shareable: Shareable? {
        @InjectService var driveInfosManager: DriveInfosManager
        return driveInfosManager.getTeam(primaryKey: id)
    }

    public var icon: UIImage {
        get async {
            // Improve this
            @InjectService var driveInfosManager: DriveInfosManager
            return driveInfosManager.getTeam(primaryKey: id)?.icon ?? UIImage()
        }
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

public class ExternInvitationFileAccess: FileAccessElement {
    public var id: Int
    public var name: String
    public var right: UserPermission
    public var color: Int?
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

    public var shareable: Shareable? {
        return nil
    }

    public var icon: UIImage {
        get async {
            if let user {
                return await withCheckedContinuation { continuation in
                    user.getAvatar { image in
                        continuation.resume(returning: image)
                    }
                }
            } else {
                return KDriveResourcesAsset.circleSend.image
            }
        }
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
