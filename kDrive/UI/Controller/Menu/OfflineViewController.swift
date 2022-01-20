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

class OfflineViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "OfflineViewController" }

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(normalFolderHierarchy: false, showUploadingFiles: false, selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.offlineFileTitle, emptyViewType: .noOffline)

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoTracker.shared.track(view: ["Menu", "Offline"])
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        let files = driveFileManager?.getAvailableOfflineFiles(sortType: sortType)
        DispatchQueue.main.async {
            completion(.success(files ?? []), false, true)
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for offline so we just fetch everything again
        forceRefresh()
    }

    override func updateChild(_ file: File, at index: Int) {
        // Remove file from list if it is not available offline anymore
        if !file.isAvailableOffline {
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
}
