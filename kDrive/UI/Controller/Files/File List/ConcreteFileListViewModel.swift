/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2024 Infomaniak Network SA

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

import Foundation
import kDriveCore
import RealmSwift

class ConcreteFileListViewModel: FileListViewModel {
    required convenience init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        let configuration = FileListViewModel.Configuration(
            emptyViewType: .emptyFolder,
            supportsDrop: true,
            rightBarButtons: [.search]
        )
        self.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
    }

    override init(configuration: FileListViewModel.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?) {
        let currentDirectory = currentDirectory ?? driveFileManager.getCachedRootFile(freeze: false)
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        observedFiles = AnyRealmCollection(AnyRealmCollection(currentDirectory.children).filesSorted(by: sortType))
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard !isLoading || cursor != nil else { return }

        startRefreshing(cursor: cursor)
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.fileListing(
            in: currentDirectory.proxify(),
            sortType: sortType,
            forceRefresh: forceRefresh
        )
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }

    override func loadActivities() async throws {
        try await loadFiles()
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .search {
            let viewModel = SearchFilesViewModel(driveFileManager: driveFileManager)
            let searchViewController = SearchViewController.instantiateInNavigationController(viewModel: viewModel)
            onPresentViewController?(.modal, searchViewController, true)
        } else {
            super.barButtonPressed(type: type)
        }
    }
}
