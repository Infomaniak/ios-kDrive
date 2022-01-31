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
import UIKit

class LastModificationsViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "LastModificationsViewController" }

    override func viewDidLoad() {
        // Set configuration
        let configuration = FileListViewModel.Configuration(normalFolderHierarchy: false, selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.lastEditsTitle, emptyViewType: .noActivitiesSolo)
        filePresenter.listType = LastModificationsViewController.self
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.lastModificationsRootFile
        }

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, "LastModifications"])
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil && currentDirectory != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
        }

        if currentDirectory.id == DriveFileManager.lastModificationsRootFile.id {
            Task {
                do {
                    let (files, moreComing) = try await driveFileManager.lastModifiedFiles(page: page)
                    completion(.success(files), moreComing, false)
                } catch {
                    completion(.failure(error), false, false)
                }
            }
        } else {
            super.getFiles(page: page, sortType: sortType, forceRefresh: forceRefresh, completion: completion)
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for Last Modifications so we just fetch everything again
        forceRefresh()
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        super.setUpHeaderView(headerView, isEmptyViewHidden: isEmptyViewHidden)
        // Hide sort button
        headerView.sortButton.isHidden = true
    }
}
