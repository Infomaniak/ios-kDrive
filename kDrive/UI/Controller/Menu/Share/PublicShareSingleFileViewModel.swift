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
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import UIKit

final class PublicShareSingleFileViewModel: PublicShareViewModel {
    let sharedFrozenFile: File

    init(
        publicShareProxy: PublicShareProxy,
        sortType: SortType,
        driveFileManager: DriveFileManager,
        sharedFrozenFile: File,
        currentDirectory: File,
        apiFetcher: PublicShareApiFetcher,
        configuration: Configuration
    ) {
        self.sharedFrozenFile = sharedFrozenFile
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)

        self.publicShareProxy = publicShareProxy
        self.sortType = sortType
        publicShareApiFetcher = apiFetcher
        title = currentDirectory.name
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        fatalError("Use init(publicShareProxy:… ) instead")
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        endRefreshing()
    }

    override func downloadAll(sender: Any?, publicShareProxy: PublicShareProxy) {
        let button = sender as? UIButton
        button?.isEnabled = false
        configuration.rightBarButtons = [.downloadingAll]
        loadButtonsConfiguration()

        downloadObserver = DownloadQueue.instance
            .observeFileDownloaded(self, fileId: sharedFrozenFile.id) { [weak self] _, error in
                self?.downloadAllCompletion(sender: sender, error: error)
            }

        DownloadQueue.instance.addPublicShareToQueue(file: sharedFrozenFile,
                                                     driveFileManager: driveFileManager,
                                                     publicShareProxy: publicShareProxy)
    }

    override func addToMyDrive(sender: Any?, publicShareProxy: PublicShareProxy) {
        guard accountManager.currentAccount != nil else {
            router.showUpsaleFloatingPanel()
            return
        }

        guard let currentUserDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        PublicShareAction().addToMyDrive(
            publicShareProxy: publicShareProxy,
            currentUserDriveFileManager: currentUserDriveFileManager,
            selectedItemsIds: [],
            exceptItemIds: [],
            onPresentViewController: { saveNavigationViewController, animated in
                onPresentViewController?(.modal, saveNavigationViewController, animated)
            },
            onSave: {
                @InjectService var matomo: MatomoUtils
                matomo.trackAddBulkToMykDrive()
            },
            onDismissViewController: { [weak self] in
                guard let self else { return }
                self.onDismissViewController?()
                self.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
            }
        )
    }
}
