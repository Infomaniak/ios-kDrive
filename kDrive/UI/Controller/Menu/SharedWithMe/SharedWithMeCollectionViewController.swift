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
import RealmSwift

class SharedWithMeCollectionViewController: FileListCollectionViewController {

    override func viewDidLoad() {
        if currentDirectory == nil {
            currentDirectory = driveFileManager.getCachedFile(id: DriveFileManager.constants.rootID) ?? DriveFileManager.sharedWithMeRootFile
        }
        super.viewDidLoad()

        if currentDirectory.id == DriveFileManager.sharedWithMeRootFile.id {
            title = "\(driveFileManager.drive.name)"
        }

        filePresenter.listType = SharedWithMeCollectionViewController.self
    }

    override func getFileActivities(directory: File) {
        if directory.isRoot {
            return
        } else {
            super.getFileActivities(directory: directory)
        }
    }
    
    override func toggleMultipleSelection() {
        if selectionMode {
            navigationItem.title = nil
            headerView?.selectView.isHidden = false
            headerView?.deleteButton.isHidden = true
            headerView?.moveButton.isHidden = true
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelMultipleSelection))
            navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
            //navigationItem.rightBarButtonItem = currentDirectory.fullyDownloaded ? selectAllBarButtonItem : loadingBarButtonItem
            navigationItem.rightBarButtonItem = nil
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
            collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
        } else {
            super.toggleMultipleSelection()
        }
    }

    override func fetchNextPage(forceRefresh: Bool = false) {
        if currentDirectory.isRoot && currentDirectory.fullyDownloaded && !forceRefresh {
            //We don't have file activities for the root in shared with me
            //Get the files from the cache
            super.fetchNextPage(forceRefresh: false)
            //Update the files online
            currentPage = 0
            super.fetchNextPage(forceRefresh: true)
        } else {
            super.fetchNextPage(forceRefresh: forceRefresh)
        }
    }

    override class func instantiate() -> SharedWithMeCollectionViewController {
        return UIStoryboard(name: "Menu", bundle: nil).instantiateViewController(withIdentifier: "SharedWithMeCollectionViewController") as! SharedWithMeCollectionViewController
    }
}
