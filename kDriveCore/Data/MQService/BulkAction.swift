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

public struct BulkAction: Encodable {
    public let action: BulkActionType
    let exceptFileIds: [Int]?
    let fileIds: [Int]?
    let parentId: Int?
    let destinationDirectoryId: Int?

    public init(action: BulkActionType, parentId: Int? = nil, exceptFileIds: [Int]? = nil, destinationDirectoryId: Int? = nil) {
        self.init(action: action, exceptFileIds: exceptFileIds, fileIds: nil, parentId: parentId, destinationDirectoryId: destinationDirectoryId)
    }

    public init(action: BulkActionType, fileIds: [Int]? = nil, destinationDirectoryId: Int? = nil) {
        self.init(action: action, exceptFileIds: nil, fileIds: fileIds, parentId: nil, destinationDirectoryId: destinationDirectoryId)
    }

    private init(action: BulkActionType, exceptFileIds: [Int]? = nil, fileIds: [Int]? = nil, parentId: Int? = nil, destinationDirectoryId: Int? = nil) {
        self.action = action
        self.exceptFileIds = exceptFileIds
        self.fileIds = fileIds
        self.parentId = parentId
        self.destinationDirectoryId = destinationDirectoryId
    }
}
