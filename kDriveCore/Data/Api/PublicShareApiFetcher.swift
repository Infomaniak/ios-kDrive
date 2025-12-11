/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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
import InfomaniakDI
import InfomaniakLogin
import Kingfisher

/// Server can notify us of publicShare limitations.
public enum PublicShareLimitation: String {
    case passwordProtected = "password_not_valid"
    case expired = "link_is_not_valid"
}

public class PublicShareApiFetcher: ApiFetcher {
    /// All status including 401 are handled by our code. A locked public share will 401, therefore we need to support it.
    private static var handledHttpStatus = Set(200 ... 500)

    override public func perform<T: Decodable>(request: DataRequest,
                                               overrideDecoder: JSONDecoder? = nil) async throws -> ValidServerResponse<T> {
        let decoder = overrideDecoder ?? self.decoder
        let validatedRequest = request.validate(statusCode: PublicShareApiFetcher.handledHttpStatus)
        let dataResponse = await validatedRequest.serializingDecodable(ApiResponse<T>.self,
                                                                       automaticallyCancelling: true,
                                                                       decoder: decoder).response
        return try handleApiResponse(dataResponse)
    }
}

public extension PublicShareApiFetcher {
    func getMetadata(driveId: Int, shareLinkUid: String) async throws -> PublicShareMetadata {
        let shareLinkInfoUrl = Endpoint.shareLinkInfo(driveId: driveId, shareLinkUid: shareLinkUid).url
        // TODO: Use authenticated token if availlable
        let request = Session.default.request(shareLinkInfoUrl)

        do {
            let metadata: PublicShareMetadata = try await perform(request: request)
            return metadata
        } catch InfomaniakError.apiError(let apiError) {
            throw apiError
        }
    }

    func getShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) async throws -> File {
        let shareLinkFileUrl = Endpoint.shareLinkFile(driveId: driveId, linkUuid: linkUuid, fileId: fileId).url
        let requestParameters: [String: String] = [
            APIUploadParameter.with.rawValue: FileWith.capabilities.rawValue
        ]
        let request = Session.default.request(shareLinkFileUrl, parameters: requestParameters)
        let shareLinkFile: File = try await perform(request: request)
        return shareLinkFile
    }

    func getShareLinkFileWithThumbnail(driveId: Int, linkUuid: String, fileId: Int) async throws -> File {
        let shareLinkFileUrl = Endpoint.shareLinkFileWithThumbnail(driveId: driveId, linkUuid: linkUuid, fileId: fileId).url
        let request = Session.default.request(shareLinkFileUrl)
        let shareLinkFile: File = try await perform(request: request)
        return shareLinkFile
    }

    /// Query a specific page
    func shareLinkFileChildren(rootFolderId: Int,
                               publicShareProxy: PublicShareProxy,
                               sortType: SortType,
                               cursor: String? = nil) async throws -> ValidServerResponse<[File]> {
        let shareLinkFileChildren = Endpoint.shareLinkFileChildren(
            driveId: publicShareProxy.driveId,
            linkUuid: publicShareProxy.shareLinkUid,
            fileId: rootFolderId,
            sortType: sortType
        )
        .cursored(cursor)
        .sorted(by: [sortType])

        let shareLinkFileChildrenUrl = shareLinkFileChildren.url
        let request = Session.default.request(shareLinkFileChildrenUrl)
        let shareLinkFiles: ValidServerResponse<[File]> = try await perform(request: request)
        return shareLinkFiles
    }

    func buildPublicShareArchive(driveId: Int,
                                 linkUuid: String,
                                 body: ArchiveBody) async throws -> DownloadArchiveResponse {
        let shareLinkArchiveUrl = Endpoint.publicShareArchive(driveId: driveId, linkUuid: linkUuid).url
        let request = Session.default.request(shareLinkArchiveUrl,
                                              method: .post,
                                              parameters: body,
                                              encoder: JSONParameterEncoder.convertToSnakeCase)
        let archiveResponse: ValidServerResponse<DownloadArchiveResponse> = try await perform(request: request)
        return archiveResponse.validApiResponse.data
    }

    func countPublicShare(drive: AbstractDrive, linkUuid: String, fileId: Int) async throws -> FileCount {
        let countUrl = Endpoint.countPublicShare(driveId: drive.id, linkUuid: linkUuid, fileId: fileId).url
        let request = Session.default.request(countUrl)
        let countResponse: ValidServerResponse<FileCount> = try await perform(request: request)
        return countResponse.validApiResponse.data
    }
}
