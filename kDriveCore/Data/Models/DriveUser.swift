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
import UIKit
import InfomaniakCore
import RealmSwift
import Kingfisher

public enum UserPermission: String, Codable, CaseIterable {
    case read
    case write
    case manage
    case delete

    public var title: String {
        switch self {
        case .read:
            return KDriveCoreStrings.Localizable.userPermissionRead
        case .write:
            return KDriveCoreStrings.Localizable.userPermissionWrite
        case .manage:
            return KDriveCoreStrings.Localizable.userPermissionManage
        case .delete:
            return KDriveCoreStrings.Localizable.buttonDelete
        }
    }

    public var icon: UIImage {
        switch self {
        case .read:
            return KDriveCoreAsset.view.image
        case .write:
            return KDriveCoreAsset.edit.image
        case .manage:
            return KDriveCoreAsset.crown.image
        case .delete:
            return KDriveCoreAsset.delete.image
        }
    }
}

public class DriveUser: Object, Codable, InfomaniakUser {
    @objc public dynamic var id: Int = -1
    @objc public dynamic var email: String = ""
    @objc private dynamic var _avatar: String = ""
    @objc private dynamic var _avatarUrl: String? = nil
    @objc public dynamic var displayName: String = ""
    @objc private dynamic var _permission: String? = nil

    public var avatar: String {
        get { return !_avatar.isBlank ? _avatar: (_avatarUrl ?? "") }
        set { }
    }

    public var permission: UserPermission? {
        set {
            _permission = newValue?.rawValue
        }
        get {
            return UserPermission(rawValue: _permission ?? "")
        }
    }

    public override init() {
    }

    public override static func primaryKey() -> String? {
        return "id"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case _avatar = "avatar"
        case _avatarUrl = "avatar_url"
        case displayName = "display_name"
        case _permission = "permission"
    }
}
