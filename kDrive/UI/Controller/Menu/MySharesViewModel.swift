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

class MySharesViewModel: ManagedFileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let configuration = Configuration(normalFolderHierarchy: false,
                                          showUploadingFiles: false,
                                          selectAllSupported: false,
                                          rootTitle: KDriveResourcesStrings.Localizable.mySharesTitle,
                                          emptyViewType: .noShared,
                                          matomoViewPath: [MatomoUtils.Views.menu.displayName, "MyShares"])
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: DriveFileManager.mySharedRootFile)
        self.files = AnyRealmCollection(driveFileManager.getRealm().objects(File.self).filter(NSPredicate(format: "users.@count > 0 AND id > 1")))
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard !isLoading || page > 1 else { return }

        if currentDirectory.canLoadChildrenFromCache && !forceRefresh {
            let (_, moreComing) = try await driveFileManager.favorites(page: page, sortType: sortType, forceRefresh: true)
            if moreComing {
                try await loadFiles(page: page + 1, forceRefresh: true)
            }
        } else {
            startRefreshing(page: page)
            defer {
                endRefreshing()
            }
            
            let (_, moreComing) = try await driveFileManager.favorites(page: page, sortType: sortType, forceRefresh: forceRefresh)
            endRefreshing()
            if moreComing {
                try await loadFiles(page: page + 1, forceRefresh: forceRefresh)
            }
        }
    }

    override func loadActivities() async throws {
        try await loadFiles(page: 1, forceRefresh: false)
    }
}
