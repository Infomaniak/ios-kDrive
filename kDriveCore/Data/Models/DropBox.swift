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

public class DropBox: Codable {
    public var id: Int
    public var url: String
    public var capabilities: DropBoxCapabilities
}

public class DropBoxCapabilities: Codable {
    public var hasPassword: Bool
    public var hasNotification: Bool
    public var hasValidity: Bool
    public var hasSizeLimit: Bool
    public var validity: DropBoxValidity
    public var size: DropBoxSize

    enum CodingKeys: String, CodingKey {
        case hasPassword = "has_password"
        case hasNotification = "has_notification"
        case hasValidity = "has_validity"
        case hasSizeLimit = "has_size_limit"
        case validity
        case size
    }
}

public class DropBoxValidity: Codable {
    public var date: Date?
    public var hasExpired: Bool?

    enum CodingKeys: String, CodingKey {
        case date
        case hasExpired = "has_expired"
    }
}

public class DropBoxSize: Codable {
    public var limit: Int?
    public var remaining: Int?
}

public enum BinarySize: Encodable {
    case bytes(Int)
    case kilobytes(Int)
    case megabytes(Int)
    case gigabytes(Int)

    public var toBytes: Int {
        switch self {
        case .bytes(let bytes):
            return bytes
        case .kilobytes(let kilobytes):
            return kilobytes * 1_024
        case .megabytes(let megabytes):
            return megabytes * 1_048_576
        case .gigabytes(let gigabytes):
            return gigabytes * 1_073_741_824
        }
    }

    public var toGigabytes: Int {
        switch self {
        case .bytes(let bytes):
            return bytes / 1_073_741_824
        case .kilobytes(let kilobytes):
            return kilobytes / 1_048_576
        case .megabytes(let megabytes):
            return megabytes / 1_024
        case .gigabytes(let gigabytes):
            return gigabytes
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toBytes)
    }
}

public struct DropBoxSettings: Encodable {
    /// Alias of the dropbox
    public var alias: String?
    /// Send an email when done
    public var emailWhenFinished: Bool
    /// Limit total size of folder (bytes)
    public var limitFileSize: BinarySize?
    /// Password for protecting the dropbox
    public var password: String?
    /// Date of validity
    public var validUntil: Date?

    public init(alias: String?, emailWhenFinished: Bool, limitFileSize: BinarySize?, password: String?, validUntil: Date?) {
        self.alias = alias
        self.emailWhenFinished = emailWhenFinished
        self.limitFileSize = limitFileSize
        self.password = password
        self.validUntil = validUntil
    }
}
