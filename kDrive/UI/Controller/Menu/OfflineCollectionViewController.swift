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

class OfflineCollectionViewController: FileListCollectionViewController {

    override var normalFolderHierarchy: Bool {
        return false
    }

    private var reachedEnd = false

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = KDriveStrings.Localizable.offlineFileTitle
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        guard driveFileManager != nil else { return }
        sortedChildren = driveFileManager.getAvailableOfflineFiles(sortType: sortType)
        updateSelectedItems(newChildren: sortedChildren)
        sortedChildren.first?.isFirstInCollection = true
        sortedChildren.last?.isLastInCollection = true

        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.refreshControl.endRefreshing()
            self.setSelectedCells()
            self.showEmptyView(.noOffline, children: self.sortedChildren)
        }
    }

    override func getFileActivities(directory: File) {
        //We don't have incremental changes for offline so we just fetch everything again
        currentPage = 0
        fetchNextPage()
    }

    override func forceRefresh() {
        sortedChildren = []
        collectionView.reloadData()
        fetchNextPage()
    }

    override func observeFileUpdated() {
        driveFileManager?.observeFileUpdated(self, fileId: nil) { [unowned self] file in
            if file.id == self.currentDirectory.id {
                DispatchQueue.main.async {
                    getFileActivities(directory: self.currentDirectory)
                }
            } else if let index = sortedChildren.firstIndex(where: { $0.id == file.id }) {
                // Remove file from list if is not available Offline anymore
                if !file.isAvailableOffline {
                    sortedChildren.remove(at: index)
                    DispatchQueue.main.async {
                        collectionView.deleteItems(at: [IndexPath(row: index, section: 0)])
                        updateCornersIfNeeded()
                        showEmptyView(.noOffline, children: self.sortedChildren)
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

                DispatchQueue.main.async {
                    collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
                }
            }
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager) -> OfflineCollectionViewController {
        let viewController = UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "OfflineCollectionViewController") as! OfflineCollectionViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - State restoration

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        navigationItem.title = KDriveStrings.Localizable.offlineFileTitle
    }
}
