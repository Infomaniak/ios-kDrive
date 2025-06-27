/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import UIKit

public extension AppRouter {
    @MainActor func showSharedWithMeView(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController
    ) {
        let destinationViewModel = SharedWithMeViewModel(driveFileManager: driveFileManager)
        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        navigationController.pushViewController(destinationViewController, animated: true)
    }

    @MainActor func showSharedFileIdView(
        driveFileManager: DriveFileManager,
        navigationController: UINavigationController,
        driveId: Int,
        fileId: Int
    ) {
        let rawPresentationOrigin = "fileList"
        guard let presentationOrigin = PresentationOrigin(rawValue: rawPresentationOrigin) else {
            return
        }

        let abstractFile = ProxyFile(driveId: driveId, id: fileId)
        let endpoint = Endpoint.file(abstractFile)

        Task {
            let file: File = try await driveFileManager.apiFetcher
                .perform(request: driveFileManager.apiFetcher.authenticatedRequest(endpoint))

            presentPreviewViewController(
                frozenFiles: [file],
                index: 0,
                driveFileManager: driveFileManager,
                normalFolderHierarchy: true,
                presentationOrigin: presentationOrigin,
                navigationController: navigationController,
                animated: true
            )
        }
    }

    @MainActor func showSharedFolderIdView(driveFileManager: DriveFileManager,
                                           navigationController: UINavigationController,
                                           folderId: Int) {
        let database = driveFileManager.database
        let matchedFrozenFolder = database.fetchObject(ofType: File.self) { lazyCollection in
            lazyCollection
                .filter("id == %@", folderId)
                .first?
                .freezeIfNeeded()
        }

        let configuration = FileListViewModel.Configuration(
            emptyViewType: .emptyFolder,
            supportsDrop: true,
            rightBarButtons: [.search]
        )
        let destinationViewModel = ConcreteFileListViewModel(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: matchedFrozenFolder
        )

        Task {
            try await destinationViewModel.loadFiles()
        }

        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        navigationController.pushViewController(destinationViewController, animated: true)
    }
}
