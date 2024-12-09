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
import InfomaniakDI
import kDriveCore
import RealmSwift
import UIKit

/// Public share view model, loading content from memory realm
final class PublicShareViewModel: InMemoryFileListViewModel {
    private var downloadObserver: ObservationToken?

    var publicShareProxy: PublicShareProxy?
    let rootProxy: ProxyFile
    var publicShareApiFetcher: PublicShareApiFetcher?

    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        guard let currentDirectory else {
            fatalError("PublicShareViewModel requires a currentDirectory to work")
        }

        let configuration = Configuration(selectAllSupported: false,
                                          rootTitle: KDriveCoreStrings.Localizable.sharedWithMeTitle,
                                          emptyViewType: .emptyFolder,
                                          supportsDrop: false,
                                          rightBarButtons: [.downloadAll],
                                          matomoViewPath: [MatomoUtils.Views.menu.displayName, "publicShare"])

        rootProxy = currentDirectory.proxify()
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        observedFiles = AnyRealmCollection(currentDirectory.children)
    }

    convenience init(
        publicShareProxy: PublicShareProxy,
        sortType: SortType,
        driveFileManager: DriveFileManager,
        currentDirectory: File,
        apiFetcher: PublicShareApiFetcher
    ) {
        self.init(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        self.publicShareProxy = publicShareProxy
        self.sortType = sortType
        publicShareApiFetcher = apiFetcher
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
                                                                          publicShareApiFetcher: publicShareApiFetcher)
        endRefreshing()
        if let nextCursor {
            try await loadFiles(cursor: nextCursor)
        }
    }

    override func barButtonPressed(sender: Any?, type: FileListBarButtonType) {
        guard downloadObserver == nil else {
            return
        }

        guard let publicShareProxy = publicShareProxy else {
            return
        }

        if type == .downloadAll {
            downloadAll(sender: sender, publicShareProxy: publicShareProxy)
        } else if type == .addToMyDrive {
            addToMyDrive(sender: sender, publicShareProxy: publicShareProxy)
        }
    }

    private func downloadAll(sender: Any?, publicShareProxy: PublicShareProxy) {
        let button = sender as? UIButton
        button?.isEnabled = false

        downloadObserver = DownloadQueue.instance
            .observeFileDownloaded(self, fileId: currentDirectory.id) { [weak self] _, error in
                Task { @MainActor in
                    defer {
                        button?.isEnabled = true
                    }

                    guard let self = self else {
                        return
                    }

                    defer {
                        self.downloadObserver?.cancel()
                        self.downloadObserver = nil
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

        DownloadQueue.instance.addPublicShareToQueue(file: currentDirectory,
                                                     driveFileManager: driveFileManager,
                                                     publicShareProxy: publicShareProxy)
    }

    private func addToMyDrive(sender: Any?, publicShareProxy: PublicShareProxy) {
        let selectedItemsIds = multipleSelectionViewModel?.selectedItems.map(\.id) ?? [] + [rootProxy.id]
        let exceptItemIds = multipleSelectionViewModel?.exceptItemIds.map { $0 } ?? []

        let saveNavigationViewController = SaveFileViewController
            .instantiateInNavigationController(driveFileManager: driveFileManager)

        if let saveViewController = saveNavigationViewController.viewControllers.first as? SaveFileViewController {
            saveViewController.publicShareFileIds = selectedItemsIds
            saveViewController.publicShareExceptIds = exceptItemIds
            saveViewController.publicShareProxy = publicShareProxy
            saveViewController.selectedDirectory = currentDirectory
        }

        onPresentViewController?(.modal, saveNavigationViewController, true)
    }
}
