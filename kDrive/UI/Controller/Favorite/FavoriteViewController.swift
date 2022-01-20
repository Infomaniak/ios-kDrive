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
import MatomoTracker
import UIKit

class FavoriteViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.favorite }
    override class var storyboardIdentifier: String { "FavoriteViewController" }

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, showUploadingFiles: false, selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.favoritesTitle, emptyViewType: .noFavorite)

        super.viewDidLoad()

        // If we didn't get any directory, use the fake root
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.favoriteRootFile
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoTracker.shared.track(view: ["Favorite"])
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
        }

        driveFileManager.getFavorites(page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, children, error in
            if let fetchedCurrentDirectory = file, let fetchedChildren = children {
                self?.currentDirectory = fetchedCurrentDirectory.isFrozen ? fetchedCurrentDirectory : fetchedCurrentDirectory.freeze()
                completion(.success(fetchedChildren), !fetchedCurrentDirectory.fullyDownloaded, true)
            } else {
                completion(.failure(error ?? DriveError.localError), false, true)
            }
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for favorites so we just fetch everything again
        // But maybe we shouldn't?
        forceRefresh()
    }

    override func updateChild(_ file: File, at index: Int) {
        // Remove file from list if it was unfavorited
        if !file.isFavorite {
            let fileId = sortedFiles[index].id
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.removeFileFromList(id: fileId)
            }
            return
        }

        let oldFile = sortedFiles[index]
        sortedFiles[index] = file

        // We don't need to call reload data if only the children were updated
        if oldFile.isContentEqual(to: file) {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
        }
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
