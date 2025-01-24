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

// MARK: - Trash

public extension Endpoint {
    private static let trashPath = "/trash"

    private static let countPath = "/count"

    static func trash(drive: AbstractDrive) -> Endpoint {
        return .driveInfo(drive: drive).appending(path: trashPath, queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func trashV2(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: trashPath)
    }

    static func emptyTrash(drive: AbstractDrive) -> Endpoint {
        return .driveInfoV2(drive: drive).appending(path: trashPath)
    }

    static func trashCount(drive: AbstractDrive) -> Endpoint {
        return .trash(drive: drive).appending(path: countPath)
    }

    static func trashedInfo(file: AbstractFile) -> Endpoint {
        return .trash(drive: ProxyDrive(id: file.driveId)).appending(
            path: "/\(file.id)",
            queryItems: [FileWith.fileExtra.toQueryItem(), noAvatarDefault()]
        )
    }

    static func trashedInfoV2(file: AbstractFile) -> Endpoint {
        return .trashV2(drive: ProxyDrive(id: file.driveId)).appending(path: "/\(file.id)")
    }

    static func trashedFiles(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: "/files", queryItems: [FileWith.fileMinimal.toQueryItem()])
    }

    static func restore(file: AbstractFile) -> Endpoint {
        return .trashedInfoV2(file: file).appending(path: "/restore")
    }

    static func trashThumbnail(file: AbstractFile, at date: Date) -> Endpoint {
        return .trashedInfoV2(file: file).appending(path: "/thumbnail", queryItems: [
            URLQueryItem(name: "t", value: "\(Int(date.timeIntervalSince1970))")
        ])
    }

    static func trashCount(of directory: AbstractFile) -> Endpoint {
        return .trashedInfo(file: directory).appending(path: countPath)
    }
}
