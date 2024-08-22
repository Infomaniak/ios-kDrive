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
    private static let sharedFileWithQuery = "with=capabilities,conversion_capabilities,supported_by"

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
    func shareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        Self.shareUrlV3.appending(path: "\(driveId)/share/\(linkUuid)/files/\(fileId)")
    }

    /// Share link file children
    func shareLinkFileChildren(driveId: Int, linkUuid: String, fileId: Int, sortType: SortType) -> Endpoint {
        let orderQuery = "order_by=\(sortType.value.apiValue)&order=\(sortType.value.order)"
        return Self.shareUrlV3.appending(path: "\(driveId)/share/\(linkUuid)/files?\(Self.sharedFileWithQuery)&\(orderQuery)")
    }

    /// Share link file thumbnail
    func shareLinkFileThumbnail(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFile(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/thumbnail")
    }

    /// Share mink file preview
    func shareLinkFilePreview(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFile(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/preview")
    }

    /// Download share link file
    func downloadShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return shareLinkFile(driveId: driveId, linkUuid: linkUuid, fileId: fileId).appending(path: "/download")
    }

    func showOfficeShareLinkFile(driveId: Int, linkUuid: String, fileId: Int) -> Endpoint {
        return Self.shareUrlV1.appending(path: "share/\(driveId)/\(linkUuid)/preview/text/\(fileId)")
    }

    func importShareLinkFiles(driveId: Int) -> Endpoint {
        return Self.shareUrlV2.appending(path: "\(driveId)/imports/sharelink")
    }
}
