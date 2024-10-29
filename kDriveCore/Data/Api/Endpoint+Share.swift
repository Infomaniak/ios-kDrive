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

    /// Share link info
    static func shareLinkInfo(driveId: Int, shareLinkUid: String) -> Endpoint {
        shareUrlV2.appending(path: "/\(driveId)/share/\(shareLinkUid)/init")
    }

    /// Share link file
    static func shareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        shareUrlV3.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)")
    }

    static func shareLinkFileV2(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        shareUrlV2.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)")
    }

    /// Share link file children
    static func shareLinkFileChildren(driveId: Int, linkUuid: String, fileId: Int, sortType: SortType) -> Endpoint {
        let orderByQuery = URLQueryItem(name: "order_by", value: sortType.value.apiValue)
        let orderQuery = URLQueryItem(name: "order", value: sortType.value.order)
        let withQuery = URLQueryItem(name: "with", value: "capabilities,conversion_capabilities,supported_by")

        let shareLinkQueryItems = [orderByQuery, orderQuery, withQuery]
        let fileChildrenEndpoint = Self.shareUrlV3.appending(path: "/\(driveId)/share/\(linkUuid)/files/\(fileId)/files")
        return fileChildrenEndpoint.appending(path: "", queryItems: shareLinkQueryItems)
    }

    /// Share link file thumbnail
    static func shareLinkFileThumbnail(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/thumbnail")
    }

    /// Share link file preview
    static func shareLinkFilePreview(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/preview")
    }

    /// Download share link file
    static func downloadShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFileV2(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/download")
    }

    func showOfficeShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return Self.shareUrlV1.appending(path: "/share/\(driveId)/\(linkUuid)/preview/text/\(fileId)")
    }

    func importShareLinkFiles(driveId: Int) -> Endpoint {
        return Self.shareUrlV2.appending(path: "/\(driveId)/imports/sharelink")
    }
}
