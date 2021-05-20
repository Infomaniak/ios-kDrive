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

import UIKit
import kDriveCore
import DifferenceKit

class FavoriteCollectionViewController: FileListCollectionViewController {

    override var normalFolderHierarchy: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = KDriveStrings.Localizable.favoritesTitle
    }

    override func forceRefresh() {
        currentPage = 0
        sortedChildren = []
        collectionView.reloadData()
        fetchNextPage()
        if currentDirectory.id == DriveFileManager.favoriteRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.favoritesTitle
        }
    }

    override func getFileActivities(directory: File) {
        // We don't have incremental changes for favorites so we just fetch everything again
        forceRefresh()
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        currentPage += 1
        driveFileManager.getFavorites(page: currentPage, sortType: sortType, forceRefresh: forceRefresh) { [self] (root, favorites, error) in
            collectionView.refreshControl?.endRefreshing()
            if let fetchedCurrentDirectory = root,
                let fetchedChildren = favorites {
                if currentDirectory == nil {
                    currentDirectory = fetchedCurrentDirectory
                }

                fetchedChildren.first?.isFirstInCollection = true
                fetchedChildren.last?.isLastInCollection = true
                showEmptyView(.noFavorite, children: fetchedChildren)

                let newChildren = sortedChildren + fetchedChildren
                let changeset = getChangesetFor(newChildren: newChildren)

                collectionView.reload(using: changeset) { newChildren in
                    sortedChildren = newChildren
                    updateSelectedItems(newChildren: newChildren)
                }

                setSelectedCells()

                if !fetchedCurrentDirectory.fullyDownloaded && view.window != nil {
                    fetchNextPage()
                }
            } else {
            }
            if sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                showEmptyView(.noNetwork, children: sortedChildren)
            }
        }
    }

    override func observeFileUpdated() {
        driveFileManager.observeFileUpdated(self, fileId: nil) { [unowned self] file in
            if file.id == self.currentDirectory.id {
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.getFileActivities(directory: strongSelf.currentDirectory)
                }
            } else if let index = sortedChildren.firstIndex(where: { $0.id == file.id }) {
                // Remove file from list if it was unfavorited
                if !file.isFavorite {
                    sortedChildren.remove(at: index)
                    DispatchQueue.main.async { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.collectionView.deleteItems(at: [IndexPath(row: index, section: 0)])
                        strongSelf.updateCornersIfNeeded()
                        strongSelf.showEmptyView(.noFavorite, children: strongSelf.sortedChildren)
                    }
                    return
                }

                let oldFile = sortedChildren[index]
                sortedChildren[index] = file
                sortedChildren.last?.isLastInCollection = true
                sortedChildren.first?.isFirstInCollection = true

                //We don't need to call reload data if only the children were updated
                if oldFile.isContentEqual(to: file) {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    self?.collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
                }
            }
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager) -> FavoriteCollectionViewController {
        let viewController = UIStoryboard(name: "Favorite", bundle: nil).instantiateViewController(withIdentifier: "FavoriteCollectionViewController") as! FavoriteCollectionViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - State restoration

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        if currentDirectory.id <= DriveFileManager.constants.rootID {
            navigationItem.title = KDriveStrings.Localizable.favoritesTitle
        }
    }

}
