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

import Foundation
import InfomaniakCore
import RealmSwift

// MARK: - Share Links

private extension Endpoint {
    func withShareLinkToken(_ token: String?) -> Endpoint {
        guard let token else { return self }
        let mergedItems = (queryItems ?? []) + [URLQueryItem(name: "sharelink_password", value: token)]
        return Endpoint(host: host, path: path, queryItems: mergedItems)
    }
}

public extension Endpoint {
    /// It is necessary to keep V1 here for backward compatibility of old links
    static var shareUrlV1: Endpoint {
        return Endpoint(hostKeypath: \.driveHost, path: "/app")
    }

    static var shareUrlV2: Endpoint {
        return Endpoint(hostKeypath: \.driveHost, path: "/2/app")
    }

    static var shareUrlV3: Endpoint {
        return Endpoint(hostKeypath: \.driveHost, path: "/3/app")
    }

    static func shareLinkFiles(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: "/files/links")
    }

    static func shareLink(file: AbstractFile) -> Endpoint {
        return .fileInfoV2(file).appending(path: "/link")
    }

    /// Share link authentication
    static func shareLinkAuthentication(driveId: Int, shareLinkUid: String) -> Endpoint {
        shareUrlV2.appending(path: "/\(driveId)/share/\(shareLinkUid)/auth")
    }

    /// Share link info
    static func shareLinkInfo(driveId: Int, shareLinkUid: String, token: String? = nil) -> Endpoint {
        return shareUrlV2.appending(path: "/\(driveId)/share/\(shareLinkUid)/init")
            .withShareLinkToken(token)
    }

    /// Share link file
    static func shareLinkFile(driveId: Int, linkUuid: String, fileId: Int, token: String? = nil) -> Endpoint {
        return shareUrlV3.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)")
            .withShareLinkToken(token)
    }

    static func shareLinkFileWithThumbnail(driveId: Int, linkUuid: String, fileId: Int, token: String? = nil) -> Endpoint {
        let withQuery = URLQueryItem(name: "with", value: "supported_by,conversion_capabilities")
        let shareLinkQueryItems = [withQuery]
        let fileChildrenEndpoint = Self.shareUrlV3.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)")
        return fileChildrenEndpoint.appending(path: "", queryItems: shareLinkQueryItems)
            .withShareLinkToken(token)
    }

    static func shareLinkFileV2(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        shareUrlV2.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)")
    }

    /// Share link file children
    static func shareLinkFileChildren(driveId: Int, linkUuid: String, fileId: Int,
                                      sortType: SortType, token: String? = nil) -> Endpoint {
        let orderByQuery = URLQueryItem(name: "order_by", value: sortType.value.apiValue)
        let orderQuery = URLQueryItem(name: "order", value: sortType.value.order)
        let withQuery = URLQueryItem(name: "with", value: "capabilities,conversion_capabilities,supported_by")

        let shareLinkQueryItems = [orderByQuery, orderQuery, withQuery]
        let fileChildrenEndpoint = Self.shareUrlV3.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)/files")
        return fileChildrenEndpoint.appending(path: "", queryItems: shareLinkQueryItems)
            .withShareLinkToken(token)
    }

    /// Share link file thumbnail
    static func shareLinkFileThumbnail(driveId: Int, linkUuid: String, fileId: Int, token: String? = nil) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/thumbnail")
            .withShareLinkToken(token)
    }

    /// Share link file preview
    static func shareLinkFilePreview(driveId: Int, linkUuid: String, fileId: Int, token: String? = nil) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/preview")
            .withShareLinkToken(token)
    }

    /// Download share link file
    static func downloadShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/download")
    }

    /// Archive files from a share link
    static func publicShareArchive(driveId: Int, linkUuid: String) -> Endpoint {
        return shareUrlV2.appending(path: "/\(driveId)/share/\(linkUuid)/archive")
    }

    /// Downloads a public share archive
    static func downloadPublicShareArchive(drive: AbstractDrive, linkUuid: String, archiveUuid: String) -> Endpoint {
        return publicShareArchive(driveId: drive.id, linkUuid: linkUuid).appending(path: "/\(archiveUuid)/download")
    }

    /// Count files of a public share folder
    static func countPublicShare(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/count")
    }

    func showOfficeShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return Self.shareUrlV1.appending(path: "/share/\(driveId)/\(linkUuid)/preview/text/\(fileId)")
    }

    static func importShareLinkFiles(destinationDrive: AbstractDrive) -> Endpoint {
        return Endpoint.driveInfoV2(drive: destinationDrive).appending(path: "/imports/sharelink")
    }
}
