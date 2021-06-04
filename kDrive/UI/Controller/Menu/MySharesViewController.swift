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

class MySharesViewController: FileListViewController {

    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "MySharesViewController" }

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, rootTitle: KDriveStrings.Localizable.mySharesTitle, emptyViewType: .noShared)
        filePresenter.listType = MySharesViewController.self
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.mySharedRootFile
        }

        super.viewDidLoad()
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil && currentDirectory != nil else {
            completion(.success([]), false, true)
            return
        }

        if currentDirectory.id == DriveFileManager.mySharedRootFile.id {
            driveFileManager.getMyShared(page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, children, error in
                if let fetchedCurrentDirectory = file, let fetchedChildren = children {
                    self?.currentDirectory = fetchedCurrentDirectory.isFrozen ? fetchedCurrentDirectory : fetchedCurrentDirectory.freeze()
                    completion(.success(fetchedChildren), !fetchedCurrentDirectory.fullyDownloaded, true)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, true)
                }
            }
        } else {
            driveFileManager.apiFetcher.getFileListForDirectory(parentId: currentDirectory.id, page: page, sortType: sortType) { response, error in
                if let data = response?.data {
                    let children = data.children
                    completion(.success(Array(children)), children.count == DriveApiFetcher.itemPerPage, false)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, false)
                }
            }
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for My Shared so we just fetch everything again
        forceRefresh()
    }

}
