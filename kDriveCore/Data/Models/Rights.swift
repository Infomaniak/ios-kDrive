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
    public var show = RealmProperty<Bool?>()
    public var read = RealmProperty<Bool?>()
    public var write = RealmProperty<Bool?>()
    public var share = RealmProperty<Bool?>()
    public var leave = RealmProperty<Bool?>()
    public var delete = RealmProperty<Bool?>()
    public var rename = RealmProperty<Bool?>()
    public var move = RealmProperty<Bool?>()
    public var createNewFolder = RealmProperty<Bool?>()
    public var createNewFile = RealmProperty<Bool?>()
    public var uploadNewFile = RealmProperty<Bool?>()
    public var moveInto = RealmProperty<Bool?>()
    public var canBecomeCollab = RealmProperty<Bool?>()
    public var canBecomeLink = RealmProperty<Bool?>()
    public var canFavorite = RealmProperty<Bool?>()

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
