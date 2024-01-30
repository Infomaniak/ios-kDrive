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

import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class FavoritesViewModel: FileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let configuration = Configuration(normalFolderHierarchy: false,
                                          showUploadingFiles: false,
                                          selectAllSupported: false,
                                          rootTitle: KDriveResourcesStrings.Localizable.favoritesTitle,
                                          tabBarIcon: KDriveResourcesAsset.star,
                                          selectedTabBarIcon: KDriveResourcesAsset.starFill,
                                          emptyViewType: .noFavorite,
                                          matomoViewPath: ["Favorite"])
        let favoritesFakeRoot = driveFileManager.getManagedFile(from: DriveFileManager.favoriteRootFile)
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: favoritesFakeRoot)
        files = AnyRealmCollection(AnyRealmCollection(favoritesFakeRoot.children.filter(NSPredicate(format: "isFavorite = true")))
            .filesSorted(by: sortType))
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard !isLoading || cursor != nil else { return }

        // Only show loading indicator if we have nothing in cache
        if !currentDirectory.canLoadChildrenFromCache {
            startRefreshing(cursor: cursor)
        }
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.favorites(cursor: cursor, sortType: sortType, forceRefresh: true)
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }
}
