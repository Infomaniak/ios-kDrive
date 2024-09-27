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
import InfomaniakCore
import InfomaniakDI
import InfomaniakLogin
import Kingfisher

public class PublicShareApiFetcher: ApiFetcher {
    override public init() {
        super.init()
    }

    public func getMetadata(driveId: Int, shareLinkUid: String) async throws -> PublicShareMetadata {
        let shareLinkInfoUrl = Endpoint.shareLinkInfo(driveId: driveId, shareLinkUid: shareLinkUid).url
        // TODO: Use authenticated token if availlable
        let request = Session.default.request(shareLinkInfoUrl)
        let metadata: PublicShareMetadata = try await perform(request: request)
        return metadata
    }

    public func getShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) async throws -> File {
        let shareLinkFileUrl = Endpoint.shareLinkFile(driveId: driveId, linkUuid: linkUuid, fileId: fileId).url
        let requestParameters: [String: String] = [
            APIUploadParameter.with.rawValue: FileWith.capabilities.rawValue
        ]
        let request = Session.default.request(shareLinkFileUrl, parameters: requestParameters)
        let shareLinkFile: File = try await perform(request: request)
        return shareLinkFile
    }

    /// Query a specific page
    public func shareLinkFileChildren(rootFolderId: Int,
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
}
