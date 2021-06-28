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
import RealmSwift
import DifferenceKit

public class Rights: Object, Codable {

    @objc public dynamic var fileId: Int = 0
    @objc public dynamic var rightsRight: String = ""
    public var show = RealmOptional<Bool>()
    public var read = RealmOptional<Bool>()
    public var write = RealmOptional<Bool>()
    public var share = RealmOptional<Bool>()
    public var leave = RealmOptional<Bool>()
    public var delete = RealmOptional<Bool>()
    public var rename = RealmOptional<Bool>()
    public var move = RealmOptional<Bool>()
    public var createNewFolder = RealmOptional<Bool>()
    public var createNewFile = RealmOptional<Bool>()
    public var uploadNewFile = RealmOptional<Bool>()
    public var moveInto = RealmOptional<Bool>()
    public var canBecomeCollab = RealmOptional<Bool>()
    public var canBecomeLink = RealmOptional<Bool>()
    public var canFavorite = RealmOptional<Bool>()

    override public init() {
        rightsRight = ""
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        show.value = try? values.decode(Bool.self, forKey: .show)
        read.value = try? values.decode(Bool.self, forKey: .read)
        write.value = try? values.decode(Bool.self, forKey: .write)
        share.value = try? values.decode(Bool.self, forKey: .share)
        leave.value = try? values.decode(Bool.self, forKey: .leave)
        delete.value = try? values.decode(Bool.self, forKey: .delete)
        rename.value = try? values.decode(Bool.self, forKey: .rename)
        move.value = try? values.decode(Bool.self, forKey: .move)
        createNewFolder.value = try? values.decode(Bool.self, forKey: .createNewFolder)
        createNewFile.value = try? values.decode(Bool.self, forKey: .createNewFile)
        uploadNewFile.value = try? values.decode(Bool.self, forKey: .uploadNewFile)
        moveInto.value = try? values.decode(Bool.self, forKey: .moveInto)
        canBecomeCollab.value = try? values.decode(Bool.self, forKey: .canBecomeCollab)
        canBecomeLink.value = try? values.decode(Bool.self, forKey: .canBecomeLink)
        canFavorite.value = try? values.decode(Bool.self, forKey: .canFavorite)
    }

    public override static func primaryKey() -> String? {
        return "fileId"
    }

    enum CodingKeys: String, CodingKey {
        case rightsRight = "right"
        case show = "show"
        case read = "read"
        case write = "write"
        case share = "share"
        case leave = "leave"
        case delete = "delete"
        case rename = "rename"
        case move = "move"
        case createNewFolder = "new_folder"
        case createNewFile = "new_file"
        case uploadNewFile = "upload_new_file"
        case moveInto = "move_into"
        case canBecomeCollab = "can_become_collab"
        case canBecomeLink = "can_become_link"
        case canFavorite = "can_favorite"
    }
}

extension Rights: Differentiable {

    public var differenceIdentifier: Int {
        return fileId
    }

    public func isContentEqual(to source: Rights) -> Bool {
        return rightsRight == source.rightsRight
            && show == source.show
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
