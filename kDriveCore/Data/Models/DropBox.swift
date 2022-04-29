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

public class DropBox: EmbeddedObject, Codable {
    @Persisted public var id: Int
    @Persisted public var url: String
    @Persisted public var capabilities: DropBoxCapabilities!
}

public class DropBoxCapabilities: EmbeddedObject, Codable {
    @Persisted public var hasPassword: Bool
    @Persisted public var hasNotification: Bool
    @Persisted public var hasValidity: Bool
    @Persisted public var hasSizeLimit: Bool
    @Persisted public var validity: DropBoxValidity!
    @Persisted public var size: DropBoxSize!

    enum CodingKeys: String, CodingKey {
        case hasPassword = "has_password"
        case hasNotification = "has_notification"
        case hasValidity = "has_validity"
        case hasSizeLimit = "has_size_limit"
        case validity
        case size
    }
}

public class DropBoxValidity: EmbeddedObject, Codable {
    @Persisted public var date: Date?
    @Persisted public var hasExpired: Bool?

    enum CodingKeys: String, CodingKey {
        case date
        case hasExpired = "has_expired"
    }
}

public class DropBoxSize: EmbeddedObject, Codable {
    @Persisted public var limit: Int?
    @Persisted public var remaining: Int?
}

public enum BinarySize: Encodable {
    case bytes(Int)
    case kilobytes(Double)
    case megabytes(Double)
    case gigabytes(Double)

    public var toBytes: Int {
        switch self {
        case .bytes(let bytes):
            return bytes
        case .kilobytes(let kilobytes):
            return Int(kilobytes * 1_024)
        case .megabytes(let megabytes):
            return Int(megabytes * 1_048_576)
        case .gigabytes(let gigabytes):
            return Int(gigabytes * 1_073_741_824)
        }
    }

    public var toGigabytes: Double {
        switch self {
        case .bytes(let bytes):
            return Double(bytes) / 1_073_741_824
        case .kilobytes(let kilobytes):
            return Double(kilobytes) / 1_048_576
        case .megabytes(let megabytes):
            return Double(megabytes) / 1_024
        case .gigabytes(let gigabytes):
            return Double(gigabytes)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toBytes)
    }
}

public struct DropBoxSettings: Encodable {
    /// Alias of the dropbox
    @NullEncodable public var alias: String?
    /// Send an email when done
    public var emailWhenFinished: Bool
    /// Limit total size of folder (bytes)
    @NullEncodable public var limitFileSize: BinarySize?
    /// Password for protecting the dropbox
    public var password: String?
    /// Date of validity
    @NullEncodable public var validUntil: Date?

    public init(alias: String?, emailWhenFinished: Bool, limitFileSize: BinarySize?, password: String?, validUntil: Date?) {
        self.alias = alias
        self.emailWhenFinished = emailWhenFinished
        self.limitFileSize = limitFileSize
        self.password = password
        self.validUntil = validUntil
    }
}
