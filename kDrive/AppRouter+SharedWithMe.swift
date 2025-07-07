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
import kDriveResources
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
    ) async {
        let rawPresentationOrigin = "fileList"
        guard let presentationOrigin = PresentationOrigin(rawValue: rawPresentationOrigin),
              let frozenFile = await driveFileManager.getFrozenFileFromAPI(
                  driveId: driveId,
                  fileId: fileId
              )
        else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSharedWithMeLink)
            return
        }

        presentPreviewViewController(
            frozenFiles: [frozenFile],
            index: 0,
            driveFileManager: driveFileManager,
            normalFolderHierarchy: true,
            presentationOrigin: presentationOrigin,
            navigationController: navigationController,
            animated: true
        )
    }

    @MainActor func showSharedFolderIdView(driveFileManager: DriveFileManager,
                                           navigationController: UINavigationController,
                                           driveId: Int,
                                           folderId: Int) async {
        guard let frozenFolder = await driveFileManager.getFrozenFileFromAPI(
            driveId: driveId,
            fileId: folderId
        ) else {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSharedWithMeLink)
            return
        }

        let configuration = FileListViewModel.Configuration(
            emptyViewType: .emptyFolder,
            supportsDrop: true,
            rightBarButtons: [.search]
        )
        let destinationViewModel = ConcreteFileListViewModel(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: frozenFolder
        )

        Task {
            try await destinationViewModel.loadFiles()
        }

        let destinationViewController = FileListViewController(viewModel: destinationViewModel)
        navigationController.pushViewController(destinationViewController, animated: true)
    }
}
