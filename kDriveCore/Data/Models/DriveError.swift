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

public class ErrorUserInfo: Codable {
    var intValue: Int? = nil
    var stringValue: String? = nil

    required public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self.intValue = intValue
        } else if let stringValue = try? container.decode(String.self) {
            self.stringValue = stringValue
        }
    }

    public init(stringValue: String) {
        self.stringValue = stringValue
    }

    public init(intValue: Int) {
        self.intValue = intValue
    }
}

public struct DriveError: Error, Equatable {

    public enum DriveErrorType: String, Codable {
        case localError
        case networkError
        case serverError
    }

    public enum UserInfoKey: String, Codable {
        case fileId
        case status
        case photoAssetId
    }

    public typealias FileId = Int
    public typealias Status = Int
    public typealias PhotoAssetId = String

    public let type: DriveErrorType
    public let code: String
    public var localizedDescription: String
    public var userInfo: [UserInfoKey: ErrorUserInfo]?

    private init(type: DriveErrorType, code: String, localizedString: String = KDriveCoreStrings.Localizable.errorGeneric) {
        self.type = type
        self.code = code
        self.localizedDescription = localizedString
    }

    public static let fileNotFound = DriveError(type: .localError, code: "fileNotFound")
    public static let photoAssetNoLongerExists = DriveError(type: .localError, code: "photoAssetNoLongerExists")
    public static let refreshToken = DriveError(type: .serverError, code: "refreshToken")
    public static let unknownToken = DriveError(type: .localError, code: "unknownToken")
    public static let localError = DriveError(type: .localError, code: "localError")
    public static let serverError = DriveError(type: .serverError, code: "serverError")
    public static let networkError = DriveError(type: .networkError, code: "networkError", localizedString: KDriveCoreStrings.Localizable.errorNetwork)
    public static let taskCancelled = DriveError(type: .localError, code: "taskCancelled")
    public static let taskExpirationCancelled = DriveError(type: .localError, code: "taskExpirationCancelled")
    public static let taskRescheduled = DriveError(type: .localError, code: "taskRescheduled")
    public static let quotaExceeded = DriveError(type: .serverError, code: "quota_exceeded_error", localizedString: KDriveCoreStrings.Localizable.notEnoughStorageDescription1)
    public static let shareLinkAlreadyExists = DriveError(type: .serverError, code: "file_share_link_already_exists", localizedString: KDriveCoreStrings.Localizable.errorShareLink)
    public static let objectNotFound = DriveError(type: .serverError, code: "object_not_found", localizedString: KDriveCoreStrings.Localizable.uploadFolderNotFoundError)
    public static let cannotCreateFileHere = DriveError(type: .serverError, code: "can_not_create_file_here_error", localizedString: KDriveCoreStrings.Localizable.errorFileCreate)
    public static let destinationAlreadyExists = DriveError(type: .serverError, code: "destination_already_exists", localizedString: KDriveCoreStrings.Localizable.errorDestinationAlreadyExists)
    public static let forbidden = DriveError(type: .serverError, code: "forbidden_error", localizedString: KDriveCoreStrings.Localizable.accessDeniedTitle)
    public static let noDrive = DriveError(type: .serverError, code: "no_drive")
    public static let conflict = DriveError(type: .serverError, code: "conflict_error", localizedString: KDriveCoreStrings.Localizable.errorConflict)
    public static let maintenance = DriveError(type: .serverError, code: "product_maintenance", localizedString: KDriveCoreStrings.Localizable.driveMaintenanceDescription)

    public static let unknownError = DriveError(type: .localError, code: "unknownError")

    private static let allErrors: [DriveError] = [fileNotFound, photoAssetNoLongerExists, refreshToken, unknownToken, localError, serverError, networkError, taskCancelled, taskExpirationCancelled, taskRescheduled, quotaExceeded, shareLinkAlreadyExists, objectNotFound, cannotCreateFileHere, destinationAlreadyExists, forbidden, noDrive, conflict, maintenance]

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    public init(apiErrorCode: String, httpStatus: Int = 400) {
        if let error = DriveError.allErrors.first(where: { $0.type == .serverError && $0.code == apiErrorCode }) {
            self = error
        } else {
            self = .errorWithUserInfo(.serverError, info: [.status: ErrorUserInfo(intValue: httpStatus)])
        }
    }

    public init(apiError: ApiError) {
        if let error = DriveError.allErrors.first(where: { $0.type == .serverError && $0.code == apiError.code }) {
            self = error
        } else {
            self = .serverError
        }
    }

    func toRealm() -> Data? {
        return try? DriveError.encoder.encode(self)
    }

    static func from(realmData: Data) -> DriveError {
        if let error = try? decoder.decode(DriveError.self, from: realmData) {
            return error
        } else {
            return .unknownError
        }
    }

    static func errorWithUserInfo(_ error: DriveError, info: [UserInfoKey: ErrorUserInfo]) -> DriveError {
        var error = error
        error.userInfo = info
        return error
    }

    public static func == (lhs: DriveError, rhs: DriveError) -> Bool {
        return lhs.code == rhs.code
    }
}

extension DriveError: LocalizedError {
    public var errorDescription: String? {
        return localizedDescription
    }
}

extension DriveError: Codable {

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(DriveErrorType.self, forKey: .type)
        code = try values.decode(String.self, forKey: .code)
        userInfo = try values.decodeIfPresent([UserInfoKey: ErrorUserInfo].self, forKey: .userInfo)
        localizedDescription = DriveError.unknownError.localizedDescription
        if let errorDescription = DriveError.allErrors.first(where: { $0.type == type && $0.code == code })?.localizedDescription {
            localizedDescription = errorDescription
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(userInfo, forKey: .userInfo)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case code
        case userInfo
    }

}
