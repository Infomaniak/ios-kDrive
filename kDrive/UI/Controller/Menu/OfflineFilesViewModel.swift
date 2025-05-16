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

import InfomaniakCoreCommonUI
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

class OfflineFilesViewModel: FileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let configuration = Configuration(normalFolderHierarchy: false,
                                          showUploadingFiles: false,
                                          isRefreshControlEnabled: true,
                                          selectAllSupported: true,
                                          rootTitle: KDriveResourcesStrings.Localizable.offlineFileTitle,
                                          emptyViewType: .noOffline,
                                          matomoViewPath: [MatomoUtils.View.menu.displayName, "Offline"])
        // We don't really need a current directory for offline files
        super.init(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: DriveFileManager.offlineRoot
        )

        let results = driveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
            lazyCollection.filter("isAvailableOffline = true")
        }

        observedFiles = AnyRealmCollection(results)
    }

    override func forceRefresh() {
        Task {
            try await driveFileManager.updateAvailableOfflineFiles()
            endRefreshing()
        }
    }

    override func shouldShowEmptyView() -> Bool {
        files.isEmpty
    }

    override func barButtonPressed(sender: Any?, type: FileListBarButtonType) {
        let viewModel = multipleSelectionViewModel
        viewModel?.isSelectAllModeEnabled = true
        viewModel?.forceMoveDistinctFiles = true
        viewModel?.rightBarButtons = [.loading]
        viewModel?.onSelectAll?()
        if type == .selectAll {
            let frozenFiles = driveFileManager.database.fetchResults(ofType: File.self) { lazyCollection in
                lazyCollection.filter("isAvailableOffline = true")
            }.freeze()
            viewModel?.didSelectFiles(Set(frozenFiles))
            viewModel?.rightBarButtons = [.deselectAll]
        } else {
            super.barButtonPressed(sender: sender, type: type)
        }
    }
}
