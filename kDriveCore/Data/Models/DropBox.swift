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
}

public class DropBoxValidity: EmbeddedObject, Codable {
    @Persisted public var date: Date?
    @Persisted public var hasExpired: Bool?
}

public class DropBoxSize: EmbeddedObject, Codable {
    @Persisted public var limit: Int?
    @Persisted public var remaining: Int?
}

/// Something to display human friendly storage size
public enum BinaryDisplaySize: Encodable {
    case bytes(UInt64)
    case kibibytes(Double)
    case mebibytes(Double)
    case gibibytes(Double)
    case tebibytes(Double)
    case pebibytes(Double)
    case exbibytes(Double)

    public var toBytes: UInt64 {
        // No need to convert bytes to bytes.
        if case .bytes(let bytes) = self {
            return bytes
        }

        let scaled = scaled(to: .bytes)
        return UInt64(scaled)
    }

    public var toKibibytes: Double {
        let scaled = scaled(to: .kibibytes)
        return scaled
    }

    public var toMebibytes: Double {
        let scaled = scaled(to: .mebibytes)
        return scaled
    }

    public var toGibibytes: Double {
        let scaled = scaled(to: .gibibytes)
        return scaled
    }

    /// Returns a storage space in the requested scale
    /// - Parameter requestedUnit: the requested scale
    /// - Returns: a scaled value
    private func scaled(to requestedUnit: UnitInformationStorage) -> Double {
        let measurement: Measurement<UnitInformationStorage>

        switch self {
        case .bytes(let bytes):
            measurement = Measurement(value: Double(bytes), unit: UnitInformationStorage.bytes)
        case .kibibytes(let kibibytes):
            measurement = Measurement(value: kibibytes, unit: UnitInformationStorage.kibibytes)
        case .mebibytes(let mebibytes):
            measurement = Measurement(value: mebibytes, unit: UnitInformationStorage.mebibytes)
        case .gibibytes(let gibibytes):
            measurement = Measurement(value: gibibytes, unit: UnitInformationStorage.gibibytes)
        case .tebibytes(let tebibytes):
            measurement = Measurement(value: tebibytes, unit: UnitInformationStorage.tebibytes)
        case .pebibytes(let pebibytes):
            measurement = Measurement(value: pebibytes, unit: UnitInformationStorage.pebibytes)
        case .exbibytes(let exbibytes):
            measurement = Measurement(value: exbibytes, unit: UnitInformationStorage.exbibytes)
        }

        let measuredBytes = measurement.converted(to: requestedUnit).value
        return measuredBytes
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
    @NullEncodable public var limitFileSize: BinaryDisplaySize?
    /// Password for protecting the dropbox
    public var password: String?
    /// Date of validity
    @NullEncodable public var validUntil: Date?

    public init(alias: String?,
                emailWhenFinished: Bool,
                limitFileSize: BinaryDisplaySize?,
                password: String?,
                validUntil: Date?) {
        self.alias = alias
        self.emailWhenFinished = emailWhenFinished
        self.limitFileSize = limitFileSize
        self.password = password
        self.validUntil = validUntil
    }
}
