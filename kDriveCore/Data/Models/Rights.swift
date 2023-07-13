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
import Foundation
import RealmSwift

public class Rights: EmbeddedObject, Codable {
    /// Right to see information
    @Persisted public var canShow: Bool
    /// Right to read content
    @Persisted public var canRead: Bool
    /// Right to write
    @Persisted public var canWrite: Bool
    /// Right to share or manage access
    @Persisted public var canShare: Bool
    /// Right to leave shared file
    @Persisted public var canLeave: Bool
    /// Right to delete
    @Persisted public var canDelete: Bool
    /// Right to rename
    @Persisted public var canRename: Bool
    /// Right to move
    @Persisted public var canMove: Bool
    /// Right to share file by link
    @Persisted public var canBecomeSharelink: Bool
    /// Right to set file as favorite
    @Persisted public var canUseFavorite: Bool
    /// Right to use and give team access
    @Persisted public var canUseTeam: Bool

    // Directory capabilities
    /// Right to add new child directory
    @Persisted public var canCreateDirectory: Bool
    /// Right to add new child file
    @Persisted public var canCreateFile: Bool
    /// Right to upload a child file
    @Persisted public var canUpload: Bool
    /// Right to move directory
    @Persisted public var canMoveInto: Bool
    /// Right to use convert directory into dropbox
    @Persisted public var canBecomeDropbox: Bool

    enum CodingKeys: String, CodingKey {
        case canShow = "can_show"
        case canRead = "can_read"
        case canWrite = "can_write"
        case canShare = "can_share"
        case canLeave = "can_leave"
        case canDelete = "can_delete"
        case canRename = "can_rename"
        case canMove = "can_move"
        case canBecomeSharelink = "can_become_sharelink"
        case canUseFavorite = "can_use_favorite"
        case canUseTeam = "can_use_team"
        case canCreateDirectory = "can_create_directory"
        case canCreateFile = "can_create_file"
        case canUpload = "can_upload"
        case canMoveInto = "can_move_into"
        case canBecomeDropbox = "can_become_dropbox"
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canShow = try container.decode(Bool.self, forKey: .canShow)
        canRead = try container.decode(Bool.self, forKey: .canRead)
        canWrite = try container.decode(Bool.self, forKey: .canWrite)
        canShare = try container.decode(Bool.self, forKey: .canShare)
        canLeave = try container.decode(Bool.self, forKey: .canLeave)
        canDelete = try container.decode(Bool.self, forKey: .canDelete)
        canRename = try container.decode(Bool.self, forKey: .canRename)
        canMove = try container.decode(Bool.self, forKey: .canMove)
        canBecomeSharelink = try container.decode(Bool.self, forKey: .canBecomeSharelink)
        canUseFavorite = try container.decode(Bool.self, forKey: .canUseFavorite)
        canUseTeam = try container.decode(Bool.self, forKey: .canUseTeam)
        canCreateDirectory = try container.decodeIfPresent(Bool.self, forKey: .canCreateDirectory) ?? false
        canCreateFile = try container.decodeIfPresent(Bool.self, forKey: .canCreateFile) ?? false
        canUpload = try container.decodeIfPresent(Bool.self, forKey: .canUpload) ?? false
        canMoveInto = try container.decodeIfPresent(Bool.self, forKey: .canMoveInto) ?? false
        canBecomeDropbox = try container.decodeIfPresent(Bool.self, forKey: .canBecomeDropbox) ?? false
    }

    override public init() {
        // We have to keep it for Realm
    }
}

extension Rights: ContentEquatable {
    public func isContentEqual(to source: Rights) -> Bool {
        return canShow == source.canShow
            && canRead == source.canRead
            && canWrite == source.canWrite
            && canShare == source.canShare
            && canLeave == source.canLeave
            && canDelete == source.canDelete
            && canRename == source.canRename
            && canMove == source.canMove
            && canBecomeSharelink == source.canBecomeSharelink
            && canUseFavorite == source.canUseFavorite
            && canUseTeam == source.canUseTeam
            && canCreateDirectory == source.canCreateDirectory
            && canCreateFile == source.canCreateFile
            && canUpload == source.canUpload
            && canMoveInto == source.canMoveInto
            && canBecomeDropbox == source.canBecomeDropbox
    }
}
