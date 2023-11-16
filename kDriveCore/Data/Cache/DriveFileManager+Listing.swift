/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

public extension DriveFileManager {
    func fileListing(in directory: ProxyFile,
                     sortType: SortType = .nameAZ,
                     forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        guard !directory.isRoot else {
            return try await files(in: directory, cursor: nil, sortType: sortType, forceRefresh: forceRefresh)
        }

        let lastCursor = forceRefresh ? nil : try directory.resolve(using: getRealm()).lastCursor

        let result = try await apiFetcher.files(in: directory, listingCursor: lastCursor, sortType: sortType)

        let children = result.data.files
        let nextCursor = result.response.cursor
        let hasMore = result.response.hasMore

        let realm = getRealm()
        // Keep cached properties for children
        for child in children {
            keepCacheAttributesForFile(newFile: child, keepProperties: [.standard, .extras], using: realm)
        }

        let managedParent = try directory.resolve(using: realm)

        try realm.write {
            managedParent.lastCursor = nextCursor
            managedParent.versionCode = DriveFileManager.constants.currentVersionCode

            realm.add(children, update: .modified)
            // ⚠️ this is important because we are going to add all the children again. However, failing to start the request with
            // the first page will result in an undefined behavior.
            if lastCursor == nil {
                managedParent.children.removeAll()
            }
            managedParent.children.insert(objectsIn: children)
        }

        return (
            getLocalSortedDirectoryFiles(directory: managedParent, sortType: sortType),
            hasMore ? nextCursor : nil
        )
    }
}
