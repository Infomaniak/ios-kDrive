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
    init(configuration: FileListViewController.Configuration, driveFileManager: DriveFileManager) {
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: DriveFileManager.favoriteRootFile)
        self.files = AnyRealmCollection(driveFileManager.getRealm().objects(File.self).filter(NSPredicate(format: "isFavorite = true")))
    }

    override func getFile(id: Int, withExtras: Bool = false, page: Int = 1, sortType: SortType = .nameAZ, forceRefresh: Bool = false, completion: @escaping (File?, [File]?, Error?) -> Void) {
        driveFileManager.getFavorites(page: page, sortType: sortType, forceRefresh: forceRefresh, completion: completion)
    }

    override func loadActivities() {
        loadFiles(page: 1, forceRefresh: true)
    }
}

class FavoriteViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.favorite }
    override class var storyboardIdentifier: String { "FavoriteViewController" }

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, showUploadingFiles: false, selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.favoritesTitle, emptyViewType: .noFavorite)
        super.viewDidLoad()
    }

    override func getViewModel() -> FileListViewModel {
        return FavoritesViewModel(configuration: configuration, driveFileManager: driveFileManager)
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
