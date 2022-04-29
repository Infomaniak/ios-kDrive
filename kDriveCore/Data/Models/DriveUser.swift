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
import InfomaniakCore
import kDriveResources
import Kingfisher
import RealmSwift
import UIKit

public enum DriveUserType: String, Codable {
    case shared
    case main
}

public enum UserPermission: String, Codable, CaseIterable {
    case read
    case write
    case manage
    case delete

    public var title: String {
        switch self {
        case .read:
            return KDriveResourcesStrings.Localizable.userPermissionRead
        case .write:
            return KDriveResourcesStrings.Localizable.userPermissionWrite
        case .manage:
            return KDriveResourcesStrings.Localizable.userPermissionManage
        case .delete:
            return KDriveResourcesStrings.Localizable.buttonDelete
        }
    }

    public var icon: UIImage {
        switch self {
        case .read:
            return KDriveResourcesAsset.view.image
        case .write:
            return KDriveResourcesAsset.edit.image
        case .manage:
            return KDriveResourcesAsset.crown.image
        case .delete:
            return KDriveResourcesAsset.delete.image
        }
    }
}

public class DriveUser: Object, Codable, InfomaniakUser {
    @Persisted(primaryKey: true) public var id: Int = -1
    @Persisted public var email: String = ""
    @Persisted private var _avatar: String = ""
    @Persisted private var _avatarUrl: String?
    @Persisted public var displayName: String = ""
    public var type: DriveUserType?

    public var avatar: String {
        return !_avatar.isBlank ? _avatar : (_avatarUrl ?? "")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case _avatar = "avatar"
        case _avatarUrl = "avatar_url"
        case displayName = "display_name"
        case type
    }

    public convenience init(user: InfomaniakCore.UserProfile) {
        self.init()
        self.id = user.id
        self.email = user.email
        self._avatar = user.avatar
        self.displayName = user.displayName
    }
}
