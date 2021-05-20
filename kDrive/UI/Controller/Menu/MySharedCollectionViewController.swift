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

class MySharedCollectionViewController: FileListCollectionViewController {

    override var normalFolderHierarchy: Bool {
        return false
    }

    private var reachedEnd = false

    override func viewDidLoad() {
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.mySharedRootFile
        }

        super.viewDidLoad()

        if currentDirectory.id == DriveFileManager.mySharedRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.mySharesTitle
        }
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        guard driveFileManager != nil && currentDirectory != nil else { return }

        currentPage += 1
        startLoading()

        if currentDirectory.id == DriveFileManager.mySharedRootFile.id {
            driveFileManager.getMyShared(page: currentPage, sortType: sortType, forceRefresh: forceRefresh) { [self] (root, myShared, error) in
                self.isLoading = false
                collectionView.refreshControl?.endRefreshing()
                if let fetchedCurrentDirectory = root,
                    let fetchedChildren = myShared {
                    if currentDirectory == nil {
                        currentDirectory = fetchedCurrentDirectory
                    }

                    fetchedChildren.first?.isFirstInCollection = true
                    fetchedChildren.last?.isLastInCollection = true
                    showEmptyView(.noShared, children: fetchedChildren)

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
                if !currentDirectory.fullyDownloaded && sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
                    showEmptyView(.noNetwork, children: sortedChildren)
                }
            }
        } else {
            driveFileManager.apiFetcher.getFileListForDirectory(parentId: currentDirectory.id, page: currentPage, sortType: sortType) { (response, error) in
                self.isLoading = false
                self.collectionView.refreshControl?.endRefreshing()
                if let data = response?.data {
                    var children = [File]()
                    children.append(contentsOf: data.children)
                    self.getNewChildren(newChildren: children)
                }
            }
        }
        if !currentDirectory.fullyDownloaded && sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
            showEmptyView(.noNetwork, children: sortedChildren)
        }
    }

    private func getNewChildren(newChildren: [File] = [], deletedChild: File? = nil) {
        sortedChildren.first?.isFirstInCollection = false
        sortedChildren.last?.isLastInCollection = false
        var newSortedChildren = sortedChildren.map({ File(value: $0) }) + newChildren

        if deletedChild != nil {
            newSortedChildren = newSortedChildren.filter { $0.id != deletedChild!.id }
        }

        newSortedChildren.first?.isFirstInCollection = true
        newSortedChildren.last?.isLastInCollection = true

        let changeSet = getChangesetFor(newChildren: newSortedChildren)
        collectionView.reload(using: changeSet) { (data) in
            sortedChildren = data
            updateSelectedItems(newChildren: data)
        }
        if newChildren.count < DriveApiFetcher.itemPerPage {
            reachedEnd = true
        }
        setSelectedCells()

        showEmptyView(.noShared, children: newSortedChildren)
    }

    override func forceRefresh() {
        currentPage = 0
        reachedEnd = false
        sortedChildren = []
        collectionView.reloadData()
        fetchNextPage(forceRefresh: true)
        if currentDirectory.id == DriveFileManager.mySharedRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.mySharesTitle
        }
    }

    override func getFileActivities(directory: File) {
        // We don't have incremental changes for MyShared so we just fetch everything again
        forceRefresh()
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if sortedChildren[indexPath.row].isDirectory {
            let sharedCV = MySharedCollectionViewController.instantiate(driveFileManager: driveFileManager)
            sharedCV.currentDirectory = sortedChildren[indexPath.row]
            self.navigationController?.pushViewController(sharedCV, animated: true)
        } else {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager) -> MySharedCollectionViewController {
        let viewController = UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "MySharedCollectionViewController") as! MySharedCollectionViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - State restoration

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        if currentDirectory.id == DriveFileManager.mySharedRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.mySharesTitle
        }
    }
}
