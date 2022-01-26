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
    init(driveFileManager: DriveFileManager) {
        let configuration = FileListViewController.Configuration(normalFolderHierarchy: false, showUploadingFiles: false, selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.favoritesTitle, emptyViewType: .noFavorite)
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: DriveFileManager.favoriteRootFile)
        self.files = AnyRealmCollection(driveFileManager.getRealm().objects(File.self).filter(NSPredicate(format: "isFavorite = true")))
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) {
        guard !isLoading || page > 1 else { return }

        isLoading = true
        if page == 1 {
            showLoadingIndicatorIfNeeded()
        }

        driveFileManager.getFavorites(page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, _, error in
            self?.isLoading = false
            self?.isRefreshIndicatorHidden = true
            if let fetchedCurrentDirectory = file {
                if !fetchedCurrentDirectory.fullyDownloaded {
                    self?.loadFiles(page: page + 1, forceRefresh: forceRefresh)
                }
            } else if let error = error as? DriveError {
                self?.onDriveError?(error)
            }
        }
    }

    override func loadActivities() {
        loadFiles(page: 1, forceRefresh: true)
    }
}

class FavoriteViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.favorite }
    override class var storyboardIdentifier: String { "FavoriteViewController" }

    override func getViewModel() -> FileListViewModel {
        return FavoritesViewModel(driveFileManager: driveFileManager)
    }

    // MARK: - State restoration

    // swiftlint:disable overridden_super_call
    override func encodeRestorableState(with coder: NSCoder) {
        // We don't need to encode anything for Favorites
    }

    // swiftlint:disable overridden_super_call
    override func decodeRestorableState(with coder: NSCoder) {
        // We don't need to decode anything for Favorites
        // DriveFileManager will be recovered from tab bar controller
    }
}
