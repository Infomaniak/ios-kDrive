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

public struct ArchiveBody: Encodable {
    /// Array of files to include in the request; required without `parentId`.
    var fileIds: [Int]?
    /// The directory containing the files to include in the request; required without `fileIds`.
    var parentId: Int?
    /// Array of files to exclude from the request; only used when `parentId` is set, meaningless otherwise.
    var exceptFileIds: [Int]?

    public init(files: [ProxyFile]) {
        self.init(parentId: nil, exceptFileIds: nil, fileIds: files.map(\.id))
    }

    public init(parentId: Int, exceptFileIds: [Int]? = nil) {
        self.init(parentId: parentId, exceptFileIds: exceptFileIds, fileIds: nil)
    }

    private init(parentId: Int? = nil, exceptFileIds: [Int]? = nil, fileIds: [Int]? = nil) {
        self.fileIds = fileIds
        self.parentId = parentId
        self.exceptFileIds = exceptFileIds
    }
}
