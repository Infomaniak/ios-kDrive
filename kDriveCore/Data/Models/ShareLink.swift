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

public enum ShareLinkPermission: String, Encodable {
    case restricted, `public`, password
}

public class ShareLink: NSObject, NSCoding, Codable {
    public var url: String
    public var right: String
    public var validUntil: Date?
    public var capabilities: ShareLinkCapabilities

    enum CodingKeys: String, CodingKey {
        case url
        case right
        case validUntil = "valid_until"
        case capabilities
    }

    public func encode(with coder: NSCoder) {
        coder.encode(url, forKey: "URL")
        coder.encode(right, forKey: "Right")
        coder.encode(validUntil, forKey: "ValidUntil")
        coder.encode(capabilities, forKey: "Capabilities")
    }

    public required init?(coder: NSCoder) {
        guard let url = coder.decodeObject(forKey: "URL") as? String,
              let right = coder.decodeObject(forKey: "Right") as? String,
              let capabilities = coder.decodeObject(of: ShareLinkCapabilities.self, forKey: "Capabilities") else {
            return nil
        }
        self.url = url
        self.right = right
        self.validUntil = coder.decodeObject(forKey: "ValidUntil") as? Date
        self.capabilities = capabilities
    }
}

public class ShareLinkCapabilities: NSObject, NSCoding, Codable {
    public var canEdit: Bool
    public var canSeeStats: Bool
    public var canSeeInfo: Bool
    public var canDownload: Bool
    public var canComment: Bool

    enum CodingKeys: String, CodingKey {
        case canEdit = "can_edit"
        case canSeeStats = "can_see_stats"
        case canSeeInfo = "can_see_info"
        case canDownload = "can_download"
        case canComment = "can_comment"
    }

    public func encode(with coder: NSCoder) {
        coder.encode(canEdit, forKey: "CanEdit")
        coder.encode(canSeeStats, forKey: "CanSeeStats")
        coder.encode(canSeeInfo, forKey: "CanSeeInfo")
        coder.encode(canDownload, forKey: "CanDownload")
        coder.encode(canComment, forKey: "CanComment")
    }

    public required init?(coder: NSCoder) {
        self.canEdit = coder.decodeBool(forKey: "CanEdit")
        self.canSeeStats = coder.decodeBool(forKey: "CanSeeStats")
        self.canSeeInfo = coder.decodeBool(forKey: "CanSeeInfo")
        self.canDownload = coder.decodeBool(forKey: "CanComment")
        self.canComment = coder.decodeBool(forKey: "CanComment")
    }
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
    /// Permission of the shared link: no restriction (public), access by authenticate and authorized user (inherit) or public but protected by a password (password).
    public var right: ShareLinkPermission
    /// Validity of the link.
    @NullEncodable
    public var validUntil: Date?

    public init(canComment: Bool? = nil, canDownload: Bool? = nil, canEdit: Bool? = nil, canSeeInfo: Bool? = nil, canSeeStats: Bool? = nil, password: String? = nil, right: ShareLinkPermission, validUntil: Date? = nil) {
        self.canComment = canComment
        self.canDownload = canDownload
        self.canEdit = canEdit
        self.canSeeInfo = canSeeInfo
        self.canSeeStats = canSeeStats
        self.password = password
        self.right = right
        self.validUntil = validUntil
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
