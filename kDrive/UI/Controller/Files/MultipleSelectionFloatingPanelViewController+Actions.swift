/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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

import CocoaLumberjackSwift
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

// MARK: - Actions

extension MultipleSelectionFloatingPanelViewController {
    func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        let action = actions[indexPath.row]
        success = true
        addAction = true
        let group = DispatchGroup()

        switch action {
        case .offline:
            offlineAction(group: group, at: indexPath)
        case .favorite:
            favoriteAction(group: group)
        case .manageCategories:
            manageCategoriesAction(group: group)
        case .folderColor:
            folderColorAction(group: group)
        case .download:
            downloadAction(group: group, at: indexPath)
        case .move:
            moveAction()
        case .duplicate:
            duplicateAction(group: group, at: indexPath)
        default:
            break
        }

        // Callback on main queue
        actionCompletion(action, group: group, at: indexPath)
    }

    private func offlineAction(group: DispatchGroup, at indexPath: IndexPath) {
        addAction = FileActionsHelper.offline(files: files, driveFileManager: driveFileManager, group: group) {
            self.downloadInProgress = true
            self.collectionView.reloadItems(at: [indexPath])
        } completion: { file, error in
            if error != nil {
                self.success = false
            }
            if let file = self.driveFileManager.getCachedFile(id: file.id) {
                self.changedFiles?.append(file)
            }
        }
    }

    private func favoriteAction(group: DispatchGroup) {
        group.enter()
        Task {
            let isFavored = try await FileActionsHelper.favorite(files: files,
                                                                 driveFileManager: driveFileManager,
                                                                 completion: favorite)
            addAction = isFavored
            group.leave()
        }
    }

    private func manageCategoriesAction(group: DispatchGroup) {
        let frozenFiles = files.map { $0.freezeIfNeeded() }
        FileActionsHelper.manageCategories(frozenFiles: frozenFiles,
                                           driveFileManager: driveFileManager,
                                           from: self,
                                           group: group,
                                           presentingParent: presentingParent)
    }

    private func folderColorAction(group: DispatchGroup) {
        FileActionsHelper.folderColor(files: files,
                                      driveFileManager: driveFileManager,
                                      from: self,
                                      presentingParent: presentingParent,
                                      group: group) { isSuccess in
            self.success = isSuccess
        }
    }

    private func downloadAction(group: DispatchGroup, at indexPath: IndexPath) {
        if !allItemsSelected,
           files.allSatisfy { $0.convertedType == .image || $0.convertedType == .video } || files.count <= 1 {
            downloadActionMediaOrSingleFile(group: group, at: indexPath)
        } else {
            downloadActionArchive(group: group, at: indexPath)
        }
    }

    private func downloadActionMediaOrSingleFile(group: DispatchGroup, at indexPath: IndexPath) {
        for file in files {
            guard !file.isDownloaded else {
                FileActionsHelper.save(file: file, from: self, showSuccessSnackBar: false)
                return
            }

            guard let observerViewController = view.window?.rootViewController else {
                return
            }

            downloadInProgress = true
            collectionView.reloadItems(at: [indexPath])
            group.enter()
            downloadQueue
                .observeFileDownloaded(observerViewController, fileId: file.id) { [weak self] _, error in
                    guard let self else { return }
                    if error == nil {
                        Task { @MainActor in
                            FileActionsHelper.save(file: file, from: self, showSuccessSnackBar: false)
                        }
                    } else {
                        success = false
                    }
                    group.leave()
                }

            if let publicShareProxy = driveFileManager.publicShareProxy {
                downloadQueue.addPublicShareToQueue(file: file,
                                                    driveFileManager: driveFileManager,
                                                    publicShareProxy: publicShareProxy,
                                                    itemIdentifier: nil,
                                                    onOperationCreated: nil,
                                                    completion: nil)
            } else {
                downloadQueue.addToQueue(file: file, userId: accountManager.currentUserId, itemIdentifier: nil)
            }
        }
    }

    private func downloadActionArchive(group: DispatchGroup, at indexPath: IndexPath) {
        if downloadInProgress,
           let currentArchiveId,
           let operation = downloadQueue.archiveOperationsInQueue[currentArchiveId] {
            group.enter()
            let alert = AlertTextViewController(
                title: KDriveResourcesStrings.Localizable.cancelDownloadTitle,
                message: KDriveResourcesStrings.Localizable.cancelDownloadDescription,
                action: KDriveResourcesStrings.Localizable.buttonYes,
                destructive: true
            ) {
                operation.cancel()
                self.downloadError = .taskCancelled
                self.success = false
                group.leave()
            }
            present(alert, animated: true)
        } else {
            downloadedArchiveUrl = nil
            downloadInProgress = true
            collectionView.reloadItems(at: [indexPath])
            group.enter()

            if let publicShareProxy = driveFileManager.publicShareProxy {
                downloadPublicShareArchivedFiles(downloadCellPath: indexPath,
                                                 publicShareProxy: publicShareProxy) { result in
                    switch result {
                    case .success(let archiveUrl):
                        self.downloadedArchiveUrl = archiveUrl
                        self.success = true
                    case .failure(let error):
                        self.downloadError = error
                        self.success = false
                    }
                    group.leave()
                }
            } else {
                downloadArchivedFiles(downloadCellPath: indexPath) { result in
                    switch result {
                    case .success(let archiveUrl):
                        self.downloadedArchiveUrl = archiveUrl
                        self.success = true
                    case .failure(let error):
                        self.downloadError = error
                        self.success = false
                    }
                    group.leave()
                }
            }
        }
    }

    private func moveAction() {
        FileActionsHelper.move(files: files,
                               exceptFileIds: exceptFileIds ?? [],
                               from: currentDirectory,
                               allItemsSelected: allItemsSelected,
                               forceMoveDistinctFiles: forceMoveDistinctFiles,
                               observer: self,
                               driveFileManager: driveFileManager) { [weak self] viewController in
            guard let self else {
                return
            }

            dismiss(animated: true) {
                self.presentingParent?.present(viewController, animated: true)
            }
        }
    }

    private func duplicateAction(group: DispatchGroup, at indexPath: IndexPath) {
        let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(
            driveFileManager: driveFileManager,
            disabledDirectoriesSelection: files.compactMap(\.parent)
        ) { [files = files.map { $0.freezeIfNeeded() }] selectedDirectory in
            Task {
                do {
                    try await self.copy(files: files, to: selectedDirectory)
                } catch {
                    self.success = false
                }
            }
            group.leave()
        }
        group.enter()
        present(selectFolderNavigationController, animated: true)
        collectionView.reloadItems(at: [indexPath])
    }

    private func actionCompletion(_ action: FloatingPanelAction, group: DispatchGroup, at indexPath: IndexPath) {
        group.notify(queue: .main) {
            if self.success {
                switch action {
                case .offline:
                    let filesUpdatedNumber = self.files.filter { !$0.isDirectory }.count
                    if self.addAction {
                        UIConstants
                            .showSnackBar(message: KDriveResourcesStrings.Localizable
                                .fileListAddOfflineConfirmationSnackbar(filesUpdatedNumber))
                    } else {
                        UIConstants
                            .showSnackBar(message: KDriveResourcesStrings.Localizable
                                .fileListRemoveOfflineConfirmationSnackbar(filesUpdatedNumber))
                    }
                case .favorite:
                    if self.addAction {
                        UIConstants
                            .showSnackBar(message: KDriveResourcesStrings.Localizable
                                .fileListAddFavoritesConfirmationSnackbar(self.files.count))
                    } else {
                        UIConstants
                            .showSnackBar(message: KDriveResourcesStrings.Localizable
                                .fileListRemoveFavoritesConfirmationSnackbar(self.files.count))
                    }
                case .folderColor:
                    UIConstants
                        .showSnackBar(message: KDriveResourcesStrings.Localizable
                            .fileListColorFolderConfirmationSnackbar(self.files.filter(\.canBeColored).count))
                case .duplicate:
                    guard self.addAction else { break }
                    UIConstants
                        .showSnackBar(message: KDriveResourcesStrings.Localizable
                            .fileListDuplicationConfirmationSnackbar(self.files.count))
                case .download:
                    guard !self.files.isEmpty && self.files
                        .allSatisfy({ $0.convertedType == .image || $0.convertedType == .video }) else { break }
                    if self.files.count <= 1, let file = self.files.first {
                        let message = file.convertedType == .image
                            ? KDriveResourcesStrings.Localizable.snackbarImageSavedConfirmation
                            : KDriveResourcesStrings.Localizable.snackbarVideoSavedConfirmation
                        UIConstants.showSnackBar(message: message)
                    } else {
                        UIConstants
                            .showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarImageVideoSaved(self.files.count))
                    }
                default:
                    break
                }
            } else {
                UIConstants.showSnackBarIfNeeded(error: self.downloadError ?? DriveError.unknownError)
            }
            self.files = self.changedFiles ?? []
            self.downloadInProgress = false
            self.collectionView.reloadItems(at: [indexPath])
            if action == .download {
                if let downloadedArchiveUrl = self.downloadedArchiveUrl {
                    // Present from root view controller if the panel is no longer presented
                    let viewController = self.view.window != nil
                        ? self
                        : self.appNavigable.topMostViewController
                    guard viewController as? UIDocumentPickerViewController == nil else { return }
                    let documentExportViewController = UIDocumentPickerViewController(
                        forExporting: [downloadedArchiveUrl],
                        asCopy: true
                    )
                    viewController?.present(documentExportViewController, animated: true)
                }
            } else {
                self.dismiss(animated: true)
            }
            self.reloadAction?()
            self.changedFiles = []
        }
    }
}
