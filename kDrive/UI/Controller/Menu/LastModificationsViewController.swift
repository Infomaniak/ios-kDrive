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
import RealmSwift
import UIKit

class LastModificationsViewModel: ManagedFileListViewModel {
    init(driveFileManager: DriveFileManager) {
        let configuration = FileListViewModel.Configuration(normalFolderHierarchy: false, selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.lastEditsTitle, emptyViewType: .noActivitiesSolo, sortingOptions: [])
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: DriveFileManager.lastModificationsRootFile)
        self.files = AnyRealmCollection(driveFileManager.getRealm().objects(File.self).filter(NSPredicate(format: "type != \"dir\"")))
        sortTypeObservation?.cancel()
        sortTypeObservation = nil
        sortType = .newer
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) {
        guard !isLoading || page > 1 else { return }

        isLoading = true
        if page == 1 {
            showLoadingIndicatorIfNeeded()
        }

        if currentDirectory.id == DriveFileManager.lastModificationsRootFile.id {
            Task {
                do {
                    let (files, moreComing) = try await driveFileManager.lastModifiedFiles(page: page)
                    completion(.success(files), moreComing, false)
                } catch {
                    completion(.failure(error), false, false)
                }
            } else if let error = error as? DriveError {
                self?.onDriveError?(error)
            }
        }
    }

    override func loadActivities() {
        loadFiles(page: 1, forceRefresh: true)
    }
}

class LastModificationsViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "LastModificationsViewController" }

    override func getViewModel() -> FileListViewModel {
        return LastModificationsViewModel(driveFileManager: driveFileManager)
    }
}
