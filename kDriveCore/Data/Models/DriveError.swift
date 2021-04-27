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

public struct DriveError: Error, Equatable {

    public enum DriveErrorType: String {
        case localError
        case networkError
        case serverError
    }

    public enum UserInfoKey: String {
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
    public var userInfo: [UserInfoKey: Any]?

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

    public static let unknownError = DriveError(type: .localError, code: "unknownError")

    private static let allErrors: [DriveError] = [fileNotFound, photoAssetNoLongerExists, refreshToken, unknownToken, localError, serverError, networkError, taskCancelled, taskExpirationCancelled, taskRescheduled, quotaExceeded, shareLinkAlreadyExists, objectNotFound, cannotCreateFileHere, destinationAlreadyExists, forbidden, noDrive, conflict]

    public init(apiErrorCode: String, httpStatus: Int = 400) {
        if let error = DriveError.allErrors.first(where: { $0.type == .serverError && $0.code == apiErrorCode }) {
            self = error
        } else {
            self = .errorWithUserInfo(.serverError, info: [.status: httpStatus])
        }
    }

    public init(apiError: ApiError) {
        if let error = DriveError.allErrors.first(where: { $0.type == .serverError && $0.code == apiError.code }) {
            self = error
        } else {
            self = .serverError
        }
    }

    //We code errors in realm with format type##code##key--value##keyn--valuen
    func toRealmString() -> String {
        var encodedValue = type.rawValue + "##" + code
        if let userInfo = userInfo {
            for (key, value) in userInfo {
                encodedValue += "##\(key)--\(value)"
            }
        }
        return encodedValue
    }

    static func from(realmString: String) -> DriveError {
        let components = realmString.components(separatedBy: "##")
        let type = DriveErrorType(rawValue: components[0])
        let code = components[1]
        if var error = allErrors.first(where: { $0.type == type && $0.code == code }) {
            var userInfo = [UserInfoKey: Any]()
            for i in 2..<components.count {
                let rawUserInfo = components[i].components(separatedBy: "##")
                if userInfo.count == 2 {
                    if let key = UserInfoKey(rawValue: rawUserInfo[0]) {
                        if key == .photoAssetId {
                            userInfo[key] = rawUserInfo[1]
                        } else if let value = Int(rawUserInfo[1]) {
                            userInfo[key] = value
                        }
                    }
                }
            }
            error.userInfo = userInfo
            return error
        } else {
            return DriveError.unknownError
        }
    }

    static func errorWithUserInfo(_ error: DriveError, info: [UserInfoKey: Any]) -> DriveError {
        var error = error
        error.userInfo = info
        return error
    }

    public static func == (lhs: DriveError, rhs: DriveError) -> Bool {
        return lhs.code == rhs.code
    }
}
