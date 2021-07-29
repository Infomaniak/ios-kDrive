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
import Kingfisher
import RealmSwift
import UIKit

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
    @Persisted(primaryKey: true) public var id: Int = -1
    @Persisted public var email: String = ""
    @Persisted private var _avatar: String = ""
    @Persisted private var _avatarUrl: String?
    @Persisted public var displayName: String = ""
    @Persisted private var _permission: String?

    public var avatar: String {
        return !_avatar.isBlank ? _avatar : (_avatarUrl ?? "")
    }

    public var permission: UserPermission? {
        get {
            return UserPermission(rawValue: _permission ?? "")
        }
        set {
            _permission = newValue?.rawValue
        }
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

// This should be fixed in the next Realm version so we won't need that anymore :)

/// Taken from https://github.com/GottaGetSwifty/CodableWrappers/blob/1b449bf3f19d3654571f00a7726786683dc950f0/Sources/CodableWrappers/OptionalWrappers.swift#L34
/// Protocol for a PropertyWrapper to properly handle Coding when the wrappedValue is Optional
public protocol OptionalCodingWrapper {
    associatedtype WrappedType: ExpressibleByNilLiteral
    init(wrappedValue: WrappedType)
}

public extension KeyedDecodingContainer {
    // This is used to override the default decoding behavior for OptionalCodingWrapper to allow a value to avoid a missing key Error
    func decode<T>(_ type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T where T: Decodable, T: OptionalCodingWrapper {
        return try decodeIfPresent(T.self, forKey: key) ?? T(wrappedValue: nil)
    }
}

extension Persisted: OptionalCodingWrapper where Value: ExpressibleByNilLiteral {}
