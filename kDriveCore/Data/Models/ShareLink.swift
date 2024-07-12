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

public enum ShareLinkPermission: String, Encodable {
    case restricted, `public`, password, inherit
}

public class ShareLink: EmbeddedObject, Codable {
    @Persisted public var url: String
    @Persisted public var right: String
    @Persisted public var validUntil: Date?
    @Persisted public var capabilities: ShareLinkCapabilities!

    public var shareLinkPermission: ShareLinkPermission? {
        ShareLinkPermission(rawValue: right)
    }
}

public class ShareLinkCapabilities: EmbeddedObject, Codable {
    @Persisted public var canEdit: Bool
    @Persisted public var canSeeStats: Bool
    @Persisted public var canSeeInfo: Bool
    @Persisted public var canDownload: Bool
    @Persisted public var canComment: Bool
}

public struct ShareLinkSettings: Encodable {
    /// Can comment the shared files.
    public var canComment: Bool?
    /// Can download share content.
    public var canDownload: Bool?
    /// User that access through link can edit file content.
    public var canEdit: Bool?
    /// Can see information about the shared file.
    public var canSeeInfo: Bool?
    /// Show statistics.
    public var canSeeStats: Bool?
    /// The password if the permission password is set.
    public var password: String?
    /// Permission of the shared link: no restriction (public), access by authenticate and authorized user (inherit) or public but
    /// protected by a password (password).
    public var right: ShareLinkPermission?
    /// Validity of the link.
    public var validUntil: Date?
    public var isFreeDrive: Bool

    private enum CodingKeys: String, CodingKey {
        case canComment, canDownload, canEdit, canSeeInfo, canSeeStats, password, right, validUntil
    }

    public init(
        canComment: Bool? = nil,
        canDownload: Bool? = nil,
        canEdit: Bool? = nil,
        canSeeInfo: Bool? = nil,
        canSeeStats: Bool? = nil,
        password: String? = nil,
        right: ShareLinkPermission?,
        validUntil: Date? = nil,
        isFreeDrive: Bool
    ) {
        self.canComment = canComment
        self.canDownload = canDownload
        self.canEdit = canEdit
        self.canSeeInfo = canSeeInfo
        self.canSeeStats = canSeeStats
        self.password = password
        self.right = right
        self.validUntil = validUntil
        self.isFreeDrive = isFreeDrive
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let canComment {
            try container.encode(canComment, forKey: .canComment)
        }
        if let canDownload {
            try container.encode(canDownload, forKey: .canDownload)
        }
        if let canEdit {
            try container.encode(canEdit, forKey: .canEdit)
        }
        if let canSeeInfo {
            try container.encode(canSeeInfo, forKey: .canSeeInfo)
        }
        if let canSeeStats {
            try container.encode(canSeeStats, forKey: .canSeeStats)
        }
        if let password {
            try container.encode(password, forKey: .password)
        }
        if let right {
            try container.encode(right, forKey: .right)
        }
        if !isFreeDrive {
            try container.encode(validUntil, forKey: .validUntil)
        }
    }
}

@propertyWrapper
public struct NullEncodable<T>: Encodable where T: Encodable {
    public var wrappedValue: T?

    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch wrappedValue {
        case .some(let value): try container.encode(value)
        case .none: try container.encodeNil()
        }
    }
}
