/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import Alamofire
import Foundation
import InfomaniakCore

struct ImportApiResponse<T: Decodable>: Decodable {
    let result: Result
    let data: T?
    let error: ApiError?

    enum Result: String, Decodable {
        case success
        case error
        case asynchronous
    }
}

public extension DriveApiFetcher {
    func copyToDrive(file: AbstractFile,
                     remotePath: String?,
                     destinationDrive: AbstractDrive,
                     destinationFolder: AbstractFile) async throws -> ExternalImport {
        guard let remotePath, !remotePath.isEmpty else {
            throw DriveError.unknownError
        }

        let request = authenticatedRequest(
            .copyToDrive(destinationDrive: destinationDrive),
            method: .post,
            parameters: DriveApiFetcher.makeCopyToDriveBody(
                file: file,
                remotePath: remotePath,
                destinationFolder: destinationFolder
            )
        )
        let validatedRequest = request.validate(statusCode: Self.importHandledHttpStatus)
        let dataResponse = await validatedRequest.serializingDecodable(ImportApiResponse<[ExternalImport]>.self,
                                                                       automaticallyCancelling: true,
                                                                       decoder: decoder).response
        guard let statusCode = dataResponse.response?.statusCode else {
            throw DriveError.unknownError
        }

        let apiResponse = try dataResponse.result.get()
        switch apiResponse.result {
        case .success, .asynchronous:
            guard let externalImport = apiResponse.data?.first else {
                throw DriveError.serverError(statusCode: statusCode)
            }
            return externalImport
        case .error:
            if let apiError = apiResponse.error {
                throw DriveError(apiError: apiError)
            } else {
                throw DriveError.serverError(statusCode: statusCode)
            }
        }
    }

    func externalImports(drive: AbstractDrive, page: Int) async throws -> ValidServerResponse<[ExternalImport]> {
        try await perform(request: authenticatedRequest(.externalImports(drive: drive, page: page)))
    }

    private static func makeCopyToDriveBody(file: AbstractFile,
                                            remotePath: String,
                                            destinationFolder: AbstractFile) -> [String: Encodable & Sendable] {
        let privatePrefix = "/Private"
        let sourcePath = remotePath.hasPrefix(privatePrefix) ? String(remotePath.dropFirst(privatePrefix.count)) : remotePath

        return [
            "application_drive_id": "\(file.driveId)",
            "directory_id": destinationFolder.id,
            "source_path": sourcePath
        ]
    }

    private static let importHandledHttpStatus: Set<Int> = {
        var allStatus = Set(200 ... 500)
        allStatus.remove(401)
        return allStatus
    }()
}
