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

class MySharesViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "MySharesViewController" }

    override func viewDidLoad() {
        // Set configuration
        let configuration = FileListViewModel.Configuration(normalFolderHierarchy: false, selectAllSupported: currentDirectory != nil && !currentDirectory.isRoot, rootTitle: KDriveResourcesStrings.Localizable.mySharesTitle, emptyViewType: .noShared)
        filePresenter.listType = MySharesViewController.self
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.mySharedRootFile
        }

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.menu.displayName, "MyShares"])
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil && currentDirectory != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
        }

        if currentDirectory.id == DriveFileManager.mySharedRootFile.id {
            Task {
                do {
                    let (files, moreComing) = try await driveFileManager.mySharedFiles(page: page, sortType: sortType)
                    completion(.success(files), moreComing, true)
                } catch {
                    completion(.failure(error), false, true)
                }
            }
        } else {
            super.getFiles(page: page, sortType: sortType, forceRefresh: forceRefresh, completion: completion)
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for My Shared so we just fetch everything again
        forceRefresh()
    }
}
