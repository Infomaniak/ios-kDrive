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
    @Persisted public var show: Bool
    @Persisted public var read: Bool
    @Persisted public var write: Bool
    @Persisted public var share: Bool
    @Persisted public var leave: Bool
    @Persisted public var delete: Bool
    @Persisted public var rename: Bool
    @Persisted public var move: Bool
    @Persisted public var createNewFolder: Bool
    @Persisted public var createNewFile: Bool
    @Persisted public var uploadNewFile: Bool
    @Persisted public var moveInto: Bool
    @Persisted public var canBecomeCollab: Bool
    @Persisted public var canBecomeLink: Bool
    @Persisted public var canFavorite: Bool

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        show = try values.decodeIfPresent(Bool.self, forKey: .show) ?? false
        read = try values.decodeIfPresent(Bool.self, forKey: .read) ?? false
        write = try values.decodeIfPresent(Bool.self, forKey: .write) ?? false
        share = try values.decodeIfPresent(Bool.self, forKey: .share) ?? false
        leave = try values.decodeIfPresent(Bool.self, forKey: .leave) ?? false
        delete = try values.decodeIfPresent(Bool.self, forKey: .delete) ?? false
        rename = try values.decodeIfPresent(Bool.self, forKey: .rename) ?? false
        move = try values.decodeIfPresent(Bool.self, forKey: .move) ?? false
        createNewFolder = try values.decodeIfPresent(Bool.self, forKey: .createNewFolder) ?? false
        createNewFile = try values.decodeIfPresent(Bool.self, forKey: .createNewFile) ?? false
        uploadNewFile = try values.decodeIfPresent(Bool.self, forKey: .uploadNewFile) ?? false
        moveInto = try values.decodeIfPresent(Bool.self, forKey: .moveInto) ?? false
        canBecomeCollab = try values.decodeIfPresent(Bool.self, forKey: .canBecomeCollab) ?? false
        canBecomeLink = try values.decodeIfPresent(Bool.self, forKey: .canBecomeLink) ?? false
        canFavorite = try values.decodeIfPresent(Bool.self, forKey: .canFavorite) ?? false
    }

    override public init() {}

    enum CodingKeys: String, CodingKey {
        case show
        case read
        case write
        case share
        case leave
        case delete
        case rename
        case move
        case createNewFolder = "new_folder"
        case createNewFile = "new_file"
        case uploadNewFile = "upload_new_file"
        case moveInto = "move_into"
        case canBecomeCollab = "can_become_collab"
        case canBecomeLink = "can_become_link"
        case canFavorite = "can_favorite"
    }
}

extension Rights: ContentEquatable {
    public func isContentEqual(to source: Rights) -> Bool {
        return show == source.show
            && read == source.read
            && write == source.write
            && share == source.share
            && leave == source.leave
            && delete == source.delete
            && rename == source.rename
            && move == source.move
            && createNewFolder == source.createNewFolder
            && createNewFile == source.createNewFile
            && uploadNewFile == source.uploadNewFile
            && moveInto == source.moveInto
            && canBecomeCollab == source.canBecomeCollab
            && canBecomeLink == source.canBecomeLink
    }
}
