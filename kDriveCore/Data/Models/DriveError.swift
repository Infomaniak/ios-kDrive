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

public class ErrorUserInfo: Codable {
    var intValue: Int?
    var stringValue: String?

    public required init(from decoder: Decoder) throws {
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

    /// Errors related to upload session
    public enum UploadSessionError: Error {
        /// Not following some of the API requirements
        case invalidDirectoryParameters

        /// File name is required
        case fileNameIsEmpty

        /// Too many chunks for the API
        case chunksNumberOutOfBounds
    }

    public enum NoDriveError: Error {
        /// Drive list is empty
        case noDrive

        /// User has only one drive and it is in maintenance
        case maintenance(drive: Drive)

        /// User has only one drive and it is blocked
        case blocked(drive: Drive)

        /// No drive file manager was found
        case noDriveFileManager
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

    private init(type: DriveErrorType,
                 code: String,
                 localizedString: String = KDriveResourcesStrings.Localizable.errorGeneric,
                 underlyingError: Error? = nil) {
        self.type = type
        self.code = code
        self.underlyingError = underlyingError
        localizedDescription = localizedString
    }

    private init(type: DriveErrorType,
                 localCode: LocalCode,
                 localizedString: String = KDriveResourcesStrings.Localizable.errorGeneric,
                 underlyingError: Error? = nil) {
        self.init(type: type, code: localCode.rawValue, localizedString: localizedString, underlyingError: underlyingError)
    }

    // MARK: - Local

    public enum LocalCode: String {
        case errorDeviceStorage
        case photoLibraryWriteAccessDenied
        case errorDownload
        case errorCache
    }

    public static let fileNotFound = DriveError(type: .localError, code: "fileNotFound")
    public static let photoAssetNoLongerExists = DriveError(type: .localError, code: "photoAssetNoLongerExists")
    public static let unknownToken = DriveError(type: .localError, code: "unknownToken")
    public static let localError = DriveError(type: .localError, code: "localError")
    public static let errorDeviceStorage = DriveError(type: .localError,
                                                      localCode: .errorDeviceStorage,
                                                      localizedString: KDriveResourcesStrings.Localizable.errorDeviceStorage)
    /// The task is cancelled by the user.
    public static let taskCancelled = DriveError(type: .localError, code: "taskCancelled")

    public static let taskExpirationCancelled = DriveError(type: .localError, code: "taskExpirationCancelled")
    public static let taskRescheduled = DriveError(type: .localError, code: "taskRescheduled")
    public static let searchCancelled = DriveError(type: .localError, code: "searchCancelled")
    public static let photoLibraryWriteAccessDenied = DriveError(type: .localError,
                                                                 localCode: .photoLibraryWriteAccessDenied,
                                                                 localizedString: KDriveResourcesStrings.Localizable
                                                                     .errorPhotoLibraryAccessLimited)
    public static let downloadFailed = DriveError(type: .localError,
                                                  localCode: .errorDownload,
                                                  localizedString: KDriveResourcesStrings.Localizable.errorDownload)
    public static let cachingFailed = DriveError(type: .localError,
                                                 localCode: .errorCache,
                                                 localizedString: KDriveResourcesStrings.Localizable.errorCache)
    public static let unknownError = DriveError(type: .localError, code: "unknownError")

    public static let uploadOverDataRestrictedError = DriveError(type: .localError,
                                                                 code: "uploadOverDataRestrictedError",
                                                                 localizedString: KDriveResourcesStrings.Localizable
                                                                     .uploadOverDataRestrictedError)
    public static let moveLocalError = DriveError(type: .localError,
                                                  code: "localMoveError",
                                                  localizedString: KDriveResourcesStrings.Localizable.errorMove)

    // MARK: - Server

    public static let refreshToken = DriveError(type: .serverError, code: "refreshToken")
    public static let serverError = DriveError(type: .serverError, code: "serverError")
    public static let noDrive = DriveError(type: .serverError, code: "no_drive")
    public static let quotaExceeded = DriveError(type: .serverError,
                                                 code: "quota_exceeded_error",
                                                 localizedString: KDriveResourcesStrings.Localizable.notEnoughStorageDescription1)
    public static let shareLinkAlreadyExists = DriveError(type: .serverError,
                                                          code: "file_share_link_already_exists",
                                                          localizedString: KDriveResourcesStrings.Localizable.errorShareLink)
    public static let objectNotFound = DriveError(type: .serverError,
                                                  code: "object_not_found",
                                                  localizedString: KDriveResourcesStrings.Localizable.uploadFolderNotFoundError)
    public static let destinationAlreadyExists = DriveError(type: .serverError,
                                                            code: "destination_already_exists",
                                                            localizedString: KDriveResourcesStrings.Localizable
                                                                .errorFileAlreadyExists)
    public static let forbidden = DriveError(type: .serverError,
                                             code: "forbidden_error",
                                             localizedString: KDriveResourcesStrings.Localizable.accessDeniedTitle)
    public static let conflict = DriveError(type: .serverError,
                                            code: "conflict_error",
                                            localizedString: KDriveResourcesStrings.Localizable.errorConflict)
    public static let productMaintenance = DriveError(type: .serverError,
                                                      code: "product_maintenance",
                                                      localizedString: KDriveResourcesStrings.Localizable
                                                          .driveMaintenanceDescription)
    public static let driveMaintenance = DriveError(type: .serverError,
                                                    code: "drive_is_in_maintenance_error",
                                                    localizedString: KDriveResourcesStrings.Localizable
                                                        .driveMaintenanceDescription)
    public static let blocked = DriveError(type: .serverError,
                                           code: "product_blocked",
                                           localizedString: KDriveResourcesStrings.Localizable.driveBlockedDescriptionPlural)
    public static let lock = DriveError(type: .serverError,
                                        code: "lock_error",
                                        localizedString: KDriveResourcesStrings.Localizable.errorFileLocked)
    public static let downloadPermission = DriveError(type: .serverError,
                                                      code: "you_must_add_at_least_one_file",
                                                      localizedString: KDriveResourcesStrings.Localizable.errorDownloadPermission)
    public static let categoryAlreadyExists = DriveError(type: .serverError,
                                                         code: "category_already_exist_error",
                                                         localizedString: KDriveResourcesStrings.Localizable
                                                             .errorCategoryAlreadyExists)
    public static let stillUploadingError = DriveError(type: .serverError,
                                                       code: "still_uploading_error",
                                                       localizedString: KDriveResourcesStrings.Localizable.errorStillUploading)

    public static let fileAlreadyExistsError = DriveError(type: .serverError, code: "file_already_exists_error")

    public static let notAuthorized = DriveError(type: .serverError, code: "not_authorized")

    public static let uploadDestinationNotFoundError = DriveError(type: .serverError, code: "upload_destination_not_found_error")

    public static let uploadDestinationNotWritableError = DriveError(
        type: .serverError,
        code: "upload_destination_not_writable_error"
    )

    public static let uploadNotTerminatedError = DriveError(type: .serverError, code: "upload_not_terminated_error")

    public static let uploadNotTerminated = DriveError(type: .serverError, code: "upload_not_terminated")

    public static let invalidUploadTokenError = DriveError(type: .serverError, code: "invalid_upload_token_error")

    public static let uploadError = DriveError(type: .serverError, code: "upload_error")

    public static let uploadFailedError = DriveError(type: .serverError, code: "upload_failed_error")

    public static let uploadTokenIsNotValid = DriveError(type: .serverError, code: "upload_token_is_not_valid")

    public static let uploadTokenCanceled = DriveError(type: .serverError, code: "upload_token_canceled")

    public static let limitExceededError = DriveError(
        type: .serverError,
        code: "limit_exceeded_error",
        localizedString: KDriveResourcesStrings.Localizable.errorLimitExceeded
    )

    public static let networkError = DriveError(
        type: .networkError,
        code: "networkError",
        localizedString: KDriveResourcesStrings.Localizable.errorNetwork
    )

    private static let allErrors: [DriveError] = [fileNotFound,
                                                  photoAssetNoLongerExists,
                                                  refreshToken,
                                                  unknownToken,
                                                  localError,
                                                  serverError,
                                                  networkError,
                                                  taskCancelled,
                                                  taskExpirationCancelled,
                                                  taskRescheduled,
                                                  quotaExceeded,
                                                  shareLinkAlreadyExists,
                                                  objectNotFound,
                                                  destinationAlreadyExists,
                                                  forbidden,
                                                  noDrive,
                                                  conflict,
                                                  productMaintenance,
                                                  driveMaintenance,
                                                  lock,
                                                  downloadPermission,
                                                  categoryAlreadyExists,
                                                  stillUploadingError,
                                                  uploadNotTerminated,
                                                  uploadNotTerminatedError,
                                                  notAuthorized,
                                                  uploadDestinationNotFoundError,
                                                  uploadDestinationNotWritableError,
                                                  invalidUploadTokenError,
                                                  uploadError,
                                                  uploadFailedError,
                                                  uploadTokenIsNotValid,
                                                  fileAlreadyExistsError,
                                                  errorDeviceStorage,
                                                  limitExceededError,
                                                  uploadOverDataRestrictedError]

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// A specific, not user facing, not localized error
    var underlyingError: Error?

    public init(apiErrorCode: String, httpStatus: Int = 400) {
        if let error = DriveError.allErrors.first(where: { $0.type == .serverError && $0.code == apiErrorCode }) {
            self = error
        } else {
            self = .serverError(statusCode: httpStatus)
        }
    }

    public init(apiError: ApiError) {
        SentryDebug.addBreadcrumb(
            message: "\(apiError)",
            category: SentryDebug.Category.apiError,
            level: .error,
            metadata: ["code": apiError.code, "description": apiError.description]
        )
        if let error = DriveError.allErrors.first(where: { $0.type == .serverError && $0.code == apiError.code }) {
            self = error.wrapping(apiError)
        } else {
            self = .serverError.wrapping(apiError)
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

    static func serverError(statusCode: Int) -> DriveError {
        return errorWithUserInfo(.serverError, info: [.status: ErrorUserInfo(intValue: statusCode)])
    }

    /// Wraps a specific detailed error into a user facing localized DriveError.
    ///
    /// Produced object has a new identity but equatable is still true
    public func wrapping(_ underlyingError: Error) -> Self {
        let error = DriveError(type: type,
                               code: code,
                               localizedString: localizedDescription,
                               underlyingError: underlyingError)
        return error
    }

    /// two `DriveError`s are identical if their `code` matches
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
        if let errorDescription = DriveError.allErrors.first(where: { $0.type == type && $0.code == code })?
            .localizedDescription {
            localizedDescription = errorDescription
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(userInfo, forKey: .userInfo)
        // TODO: Underlying error
    }

    enum CodingKeys: String, CodingKey {
        case type
        case code
        case userInfo
    }
}
