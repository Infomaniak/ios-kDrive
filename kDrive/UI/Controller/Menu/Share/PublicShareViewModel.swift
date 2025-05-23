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

import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import RealmSwift
import UIKit

/// Public share view model, loading content from memory realm
class PublicShareViewModel: InMemoryFileListViewModel {
    @LazyInjectService private var matomo: MatomoUtils
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable
    @LazyInjectService var deeplinkService: DeeplinkServiceable
    @LazyInjectService var downloadQueue: DownloadQueueable

    let rootProxy: ProxyFile
    var publicShareProxy: PublicShareProxy?
    var publicShareApiFetcher: PublicShareApiFetcher?
    var downloadObserver: ObservationToken?

    override init(configuration: Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        rootProxy = currentDirectory.proxify()
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        observedFiles = AnyRealmCollection(currentDirectory.children)
    }

    convenience init(
        publicShareProxy: PublicShareProxy,
        sortType: SortType,
        driveFileManager: DriveFileManager,
        currentDirectory: File,
        apiFetcher: PublicShareApiFetcher,
        configuration: Configuration
    ) {
        self.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)

        self.publicShareProxy = publicShareProxy
        self.sortType = sortType
        publicShareApiFetcher = apiFetcher
    }

    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        fatalError("Use init(publicShareProxy:… ) instead")
    }

    override func loadFiles(cursor: String? = nil, forceRefresh: Bool = false) async throws {
        guard !isLoading || cursor != nil,
              let publicShareProxy,
              let publicShareApiFetcher else {
            return
        }

        // Only show loading indicator if we have nothing in cache
        if !currentDirectory.canLoadChildrenFromCache {
            startRefreshing(cursor: cursor)
        }
        defer {
            endRefreshing()
        }

        let (_, nextCursor) = try await driveFileManager.publicShareFiles(rootProxy: rootProxy,
                                                                          publicShareProxy: publicShareProxy,
                                                                          cursor: cursor,
                                                                          publicShareApiFetcher: publicShareApiFetcher)
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }

    override func barButtonPressed(sender: Any?, type: FileListBarButtonType) {
        guard let publicShareProxy else {
            return
        }

        if type == .downloadAll {
            downloadAll(sender: sender, publicShareProxy: publicShareProxy)
        } else if type == .downloadingAll {
            cancelDownloadAll()
        } else if type == .addToMyDrive {
            addToMyDrive(sender: sender, publicShareProxy: publicShareProxy)
        } else if type == .cancel, !(multipleSelectionViewModel?.isMultipleSelectionEnabled ?? true) {
            deeplinkService.clearLastPublicShare()
            onDismissViewController?()
        } else {
            super.barButtonPressed(sender: sender, type: type)
        }
    }

    private func cancelDownloadAll() {
        downloadQueue.cancelFileOperation(for: currentDirectory.id)
        clearDownloadObserver()
        configuration.rightBarButtons = [.downloadAll]
        loadButtonsConfiguration()
    }

    func downloadAll(sender: Any?, publicShareProxy: PublicShareProxy) {
        let button = sender as? UIButton
        button?.isEnabled = false
        configuration.rightBarButtons = [.downloadingAll]
        loadButtonsConfiguration()

        downloadObserver = downloadQueue
            .observeFileDownloaded(self, fileId: currentDirectory.id) { [weak self] _, error in
                self?.downloadAllCompletion(sender: sender, error: error)
            }

        downloadQueue.addPublicShareToQueue(file: currentDirectory,
                                            driveFileManager: driveFileManager,
                                            publicShareProxy: publicShareProxy,
                                            itemIdentifier: nil,
                                            onOperationCreated: nil,
                                            completion: nil)
    }

    func downloadAllCompletion(sender: Any?, error: Error?) {
        Task { @MainActor in
            let button = sender as? UIButton
            defer {
                button?.isEnabled = true
                self.configuration.rightBarButtons = [.downloadAll]
                self.loadButtonsConfiguration()
            }

            defer {
                self.clearDownloadObserver()
            }

            guard error == nil else {
                UIConstants.showSnackBarIfNeeded(error: DriveError.downloadFailed)
                return
            }

            // present share sheet
            let activityViewController = UIActivityViewController(
                activityItems: [self.currentDirectory.localUrl],
                applicationActivities: nil
            )

            if let senderItem = sender as? UIBarButtonItem {
                activityViewController.popoverPresentationController?.barButtonItem = senderItem
            } else if let button = button {
                activityViewController.popoverPresentationController?.sourceRect = button.frame
            } else {
                fatalError("No sender button")
            }

            self.onPresentViewController?(.modal, activityViewController, true)
        }
    }

    func clearDownloadObserver() {
        downloadObserver?.cancel()
        downloadObserver = nil
    }

    func addToMyDrive(sender: Any?, publicShareProxy: PublicShareProxy) {
        guard accountManager.currentAccount != nil else {
            router.showUpsaleFloatingPanel()
            return
        }

        guard let currentUserDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        var selectedItemsIds = multipleSelectionViewModel?.selectedItems.map(\.id) ?? []
        let exceptItemIds = multipleSelectionViewModel?.exceptItemIds.map { $0 } ?? []

        if publicShareProxy.fileId != rootProxy.id, selectedItemsIds.isEmpty {
            selectedItemsIds += [rootProxy.id]
        }

        PublicShareAction().addToMyDrive(
            publicShareProxy: publicShareProxy,
            currentUserDriveFileManager: currentUserDriveFileManager,
            selectedItemsIds: selectedItemsIds,
            exceptItemIds: exceptItemIds,
            onPresentViewController: { saveNavigationViewController, animated in
                onPresentViewController?(.modal, saveNavigationViewController, animated)
            },
            onSave: {
                self.trackAddBulkToMykDrive()
            },
            onDismissViewController: { [weak self] in
                guard let self else { return }
                self.onDismissViewController?()
                self.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
            }
        )
    }
}
