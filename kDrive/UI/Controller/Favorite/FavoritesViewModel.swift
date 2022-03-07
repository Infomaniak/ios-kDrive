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

class FavoritesViewModel: ManagedFileListViewModel {
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
        self.files = AnyRealmCollection(driveFileManager.getRealm().objects(File.self)
            .filter(NSPredicate(format: "isFavorite = true AND NOT(rawStatus IN %@)", [FileStatus.trashed.rawValue, FileStatus.trashInherited.rawValue])))
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard !isLoading || page > 1 else { return }

        if currentDirectory.canLoadChildrenFromCache && !forceRefresh {
            try await loadActivitiesIfNeeded()
        } else {
            startRefreshing(page: page)
            defer {
                endRefreshing()
            }

            let (_, moreComing) = try await driveFileManager.favorites(page: page, sortType: sortType, forceRefresh: forceRefresh)
            endRefreshing()
            if moreComing {
                try await loadFiles(page: page + 1, forceRefresh: forceRefresh)
            } else if !forceRefresh {
                try await loadActivities()
            }
        }
    }

    override func loadActivities() async throws {
        try await driveFileManager.activities(ofTypes: [.fileFavoriteCreate, .fileFavoriteRemove], fakeRoot: DriveFileManager.favoriteRootFile)
    }
}
