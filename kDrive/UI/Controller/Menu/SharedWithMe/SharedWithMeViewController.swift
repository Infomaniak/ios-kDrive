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
import UIKit

class SharedWithMeViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "SharedWithMeViewController" }

    override func viewDidLoad() {
        // Set configuration
        let  configuration = FileListViewModel.Configuration(selectAllSupported: currentDirectory != nil && !currentDirectory.isRoot, emptyViewType: .noSharedWithMe, supportsDrop: currentDirectory != nil)
        if currentDirectory == nil {
            currentDirectory = driveFileManager?.getCachedRootFile() ?? DriveFileManager.sharedWithMeRootFile
        }

        super.viewDidLoad()
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil && currentDirectory != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
        }

        if currentDirectory.isRoot && currentDirectory.fullyDownloaded && !forceRefresh {
            // We don't have file activities for the root in shared with me
            // Get the files from the cache
            super.getFiles(page: page, sortType: sortType, forceRefresh: false, completion: completion)
            // Update the files online
            super.getFiles(page: 1, sortType: sortType, forceRefresh: true, completion: completion)
        } else {
            super.getFiles(page: page, sortType: sortType, forceRefresh: forceRefresh, completion: completion)
        }
    }

    override func getNewChanges() {
        if currentDirectory.isRoot {
            forceRefresh()
        } else {
            super.getNewChanges()
        }
    }
}
