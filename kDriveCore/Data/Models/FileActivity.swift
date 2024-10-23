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

import DifferenceKit
import InfomaniakCore
import InfomaniakDI
import RealmSwift
import UIKit

public enum FileActivityType: String, Codable, CaseIterable {
    case fileAccess = "file_access"
    case fileCreate = "file_create"
    case fileRename = "file_rename"
    case fileMoveIn = "file_move"
    case fileMoveOut = "file_move_out"
    case fileTrash = "file_trash"
    case fileRestore = "file_restore"
    case fileDelete = "file_delete"
    case fileUpdate = "file_update"
    case fileCategorize = "file_categorize"
    case fileUncategorize = "file_uncategorize"
    case fileFavoriteCreate = "file_favorite_create"
    case fileFavoriteRemove = "file_favorite_remove"
    case fileShareCreate = "file_share_create"
    case fileShareUpdate = "file_share_update"
    case fileShareDelete = "file_share_delete"
    case shareLinkCreate = "share_link_create"
    case shareLinkUpdate = "share_link_update"
    case shareLinkDelete = "share_link_delete"
    case shareLinkShow = "share_link_show"
    case commentCreate = "comment_create"
    case commentUpdate = "comment_update"
    case commentDelete = "comment_delete"
    case commentLike = "comment_like"
    case commentUnlike = "comment_unlike"
    case commentResolve = "comment_resolve"
    case collaborativeFolderAccess = "collaborative_folder_access"
    case collaborativeFolderCreate = "collaborative_folder_create"
    case collaborativeFolderUpdate = "collaborative_folder_update"
    case collaborativeFolderDelete = "collaborative_folder_delete"
    case collaborativeUserAccess = "collaborative_user_access"
    case collaborativeUserCreate = "collaborative_user_create"
    case collaborativeUserDelete = "collaborative_user_delete"
    case fileColorUpdate = "file_color_update"
    case fileColorDelete = "file_color_delete"

    public static let displayedFileActivities: [FileActivityType] = [
        .fileCreate,
        .fileRename,
        .fileMoveIn,
        .fileMoveOut,
        .fileTrash,
        .fileRestore,
        .fileDelete,
        .fileUpdate,
        .fileCategorize,
        .fileUncategorize,
        .fileFavoriteCreate,
        .fileFavoriteRemove,
        .fileShareCreate,
        .fileShareUpdate,
        .fileShareDelete,
        .shareLinkCreate,
        .shareLinkUpdate,
        .shareLinkDelete,
        .shareLinkShow,
        .collaborativeFolderCreate,
        .collaborativeFolderUpdate,
        .collaborativeFolderDelete,
        .fileColorUpdate,
        .fileColorDelete
    ]
}

public class FileActivity: Object, Decodable {
    @LazyInjectService var driveInfosManager: DriveInfosManager

    @Persisted(primaryKey: true) public var id = UUID().uuidString.hashValue
    /// Date Activity File was created at
    @Persisted public var createdAt: Date
    /// Use `action` instead
    @Persisted private var rawAction: String
    /// Current path of the activity file/directory
    @Persisted public var newPath: String
    /// Previous path of the activity file/directory
    @Persisted public var oldPath: String
    /// Logged file identifier
    @Persisted public var fileId: Int
    /// Use `user` to access the complete object
    @Persisted public var userId: Int?
    /// Associated File or Directory, null is element was deleted
    @Persisted public var file: File?

    public var mergedFileActivities: [FileActivity] = []

    /// Activity type
    public var action: FileActivityType? {
        return FileActivityType(rawValue: rawAction)
    }

    public var user: DriveUser? {
        if let id = userId {
            return driveInfosManager.getUser(primaryKey: id)
        } else {
            return nil
        }
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userContainer = try? container.nestedContainer(keyedBy: UserCodingKeys.self, forKey: .user)

        id = try container.decode(Int.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        rawAction = try container.decode(String.self, forKey: .action)
        newPath = try container.decode(String.self, forKey: .newPath)
        oldPath = try container.decode(String.self, forKey: .oldPath)
        fileId = try container.decode(Int.self, forKey: .fileId)
        userId = try userContainer?.decode(Int.self, forKey: .id)
        file = try container.decodeIfPresent(File.self, forKey: .file)
    }

    override public init() {
        // Required by Realm
        super.init()
        // primary key is set as default value
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case action
        case newPath
        case oldPath
        case fileId
        case user
        case file
    }

    enum UserCodingKeys: String, CodingKey {
        case id
    }
}

extension FileActivity: ContentIdentifiable, ContentEquatable {
    public func isContentEqual(to source: FileActivity) -> Bool {
        return id == source.id && mergedFileActivities.isContentEqual(to: source.mergedFileActivities)
    }
}

public class ActivitiesForFile: Decodable {
    public var id: Int
    public var result: Bool
    public var message: String?
    public var file: File?
    public var activities: [FileActivity]
}
