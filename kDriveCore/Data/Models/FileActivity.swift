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
import RealmSwift
import UIKit

public enum FileActivityType: String, Codable, CaseIterable {
    case fileAccess
    case fileCreate
    case fileRename
    case fileMoveIn = "file_move"
    case fileMoveOut
    case fileTrash
    case fileRestore
    case fileDelete
    case fileUpdate
    case fileCategorize
    case fileUncategorize
    case fileFavoriteCreate
    case fileFavoriteRemove
    case fileShareCreate
    case fileShareUpdate
    case fileShareDelete
    case shareLinkCreate
    case shareLinkUpdate
    case shareLinkDelete
    case shareLinkShow
    case commentCreate
    case commentUpdate
    case commentDelete
    case commentLike
    case commentUnlike
    case commentResolve
    case collaborativeFolderAccess
    case collaborativeFolderCreate
    case collaborativeFolderUpdate
    case collaborativeFolderDelete
    case collaborativeUserAccess
    case collaborativeUserCreate
    case collaborativeUserDelete
    case fileColorUpdate
    case fileColorDelete

    public static let fileActivities: [FileActivityType] = [
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

    public static let displayedFileActivities: [FileActivityType] = FileActivityType.allCases
}

public class FileActivity: Object, Decodable {
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
            return DriveInfosManager.instance.getUser(id: id)
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
