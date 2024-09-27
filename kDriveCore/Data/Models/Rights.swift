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

    // MARK: Directory capabilities

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

    // MARK: Public share

    /// Can edit
    @Persisted public var canEdit: Bool
    /// Can see stats
    @Persisted public var canSeeStats: Bool
    /// Can see info
    @Persisted public var canSeeInfo: Bool
    /// Can download
    @Persisted public var canDownload: Bool
    /// Can comment
    @Persisted public var canComment: Bool
    /// Can request access
    @Persisted public var canRequestAccess: Bool

    enum CodingKeys: String, CodingKey {
        case canShow
        case canRead
        case canWrite
        case canShare
        case canLeave
        case canDelete
        case canRename
        case canMove
        case canBecomeSharelink
        case canUseFavorite
        case canUseTeam
        case canCreateDirectory
        case canCreateFile
        case canUpload
        case canMoveInto
        case canBecomeDropbox
        case canEdit
        case canSeeStats
        case canSeeInfo
        case canDownload
        case canComment
        case canRequestAccess
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canShow = try container.decodeIfPresent(Bool.self, forKey: .canShow) ?? true
        canRead = try container.decodeIfPresent(Bool.self, forKey: .canRead) ?? true
        canWrite = try container.decodeIfPresent(Bool.self, forKey: .canWrite) ?? false
        canShare = try container.decodeIfPresent(Bool.self, forKey: .canShare) ?? false
        canLeave = try container.decodeIfPresent(Bool.self, forKey: .canLeave) ?? false
        canDelete = try container.decodeIfPresent(Bool.self, forKey: .canDelete) ?? false
        canRename = try container.decodeIfPresent(Bool.self, forKey: .canRename) ?? false
        canMove = try container.decodeIfPresent(Bool.self, forKey: .canMove) ?? false
        canBecomeSharelink = try container.decodeIfPresent(Bool.self, forKey: .canBecomeSharelink) ?? false
        canUseFavorite = try container.decodeIfPresent(Bool.self, forKey: .canUseFavorite) ?? false
        canUseTeam = try container.decodeIfPresent(Bool.self, forKey: .canUseTeam) ?? false
        canCreateDirectory = try container.decodeIfPresent(Bool.self, forKey: .canCreateDirectory) ?? false
        canCreateFile = try container.decodeIfPresent(Bool.self, forKey: .canCreateFile) ?? false
        canUpload = try container.decodeIfPresent(Bool.self, forKey: .canUpload) ?? false
        canMoveInto = try container.decodeIfPresent(Bool.self, forKey: .canMoveInto) ?? false
        canBecomeDropbox = try container.decodeIfPresent(Bool.self, forKey: .canBecomeDropbox) ?? false
        canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
        canSeeStats = try container.decodeIfPresent(Bool.self, forKey: .canSeeStats) ?? false
        canSeeInfo = try container.decodeIfPresent(Bool.self, forKey: .canSeeInfo) ?? false
        canDownload = try container.decodeIfPresent(Bool.self, forKey: .canDownload) ?? false
        canComment = try container.decodeIfPresent(Bool.self, forKey: .canComment) ?? false
        canRequestAccess = try container.decodeIfPresent(Bool.self, forKey: .canRequestAccess) ?? false
    }

    override public init() {
        // Required by Realm
        super.init()
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
