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

class LastModificationsViewController: FileListCollectionViewController {

    override var normalFolderHierarchy: Bool {
        return false
    }

    private var reachedEnd = false

    override func viewDidLoad() {
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.lastModificationsRootFile
        }

        super.viewDidLoad()

        if currentDirectory.id == DriveFileManager.lastModificationsRootFile.id {
            navigationItem.title = KDriveStrings.Localizable.lastEditsTitle
        }
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        currentPage += 1
        if currentDirectory.id == DriveFileManager.lastModificationsRootFile.id {
            driveFileManager.apiFetcher.getLastModifiedFiles(page: currentPage) { (response, error) in
                self.collectionView.refreshControl?.endRefreshing()
                if let data = response?.data {
                    self.getNewChildren(newChildren: data)
                }
            }
        } else {
            driveFileManager.apiFetcher.getFileListForDirectory(parentId: currentDirectory.id, page: currentPage) { (response, error) in
                self.collectionView.refreshControl?.endRefreshing()
                if let data = response?.data {
                    var children = [File]()
                    children.append(contentsOf: data.children)
                    self.getNewChildren(newChildren: children)
                }
            }
        }
        if !currentDirectory.fullyDownloaded && sortedChildren.isEmpty && ReachabilityListener.instance.currentStatus == .offline {
            showEmptyView(.noActivitiesSolo, children: sortedChildren)
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
    }
    
    override func getFileActivities(directory: File) {
        //We don't have incremental changes for LastModifications so we just fetch everything again
        forceRefresh()
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
        (headerView as? FilesHeaderView)?.sortButton.isHidden = true

        return headerView
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if sortedChildren[indexPath.row].isDirectory {
            let sharedCV = LastModificationsViewController.instantiate()
            sharedCV.currentDirectory = sortedChildren[indexPath.row]
            self.navigationController?.pushViewController(sharedCV, animated: true)
        } else {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }

    override class func instantiate() -> LastModificationsViewController {
        return UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "LastModificationsViewController") as! LastModificationsViewController
    }

}
