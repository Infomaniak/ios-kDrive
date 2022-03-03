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

class SelectFloatingPanelTableViewController: FileActionsFloatingPanelViewController {
    var files = [File]()
    var allItemsSelected = false
    var exceptFileIds: [Int]?
    var parentId: Int?
    var changedFiles: [File]? = []
    var downloadInProgress = false
    var reloadAction: (() -> Void)?

    override class var sections: [Section] {
        return [.actions]
    }

    var filesAvailableOffline: Bool {
        return files.allSatisfy(\.isAvailableOffline)
    }

    var filesAreFavorite: Bool {
        return files.allSatisfy(\.isFavorite)
    }

    private var success = true
    private var downloadedArchiveUrl: URL?
    private var currentArchiveId: String?
    private var downloadError: DriveError?

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.alwaysBounceVertical = false
        setupContent()
    }

    override func setupContent() {
        if sharedWithMe {
            actions = FloatingPanelAction.multipleSelectionSharedWithMeActions
        } else if files.count > Constants.bulkActionThreshold || allItemsSelected {
            actions = FloatingPanelAction.multipleSelectionBulkActions
        } else {
            actions = FloatingPanelAction.multipleSelectionActions
        }
    }

    override func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        let action = actions[indexPath.row]
        success = true
        var addAction = true
        let group = DispatchGroup()

        switch action {
        case .offline:
            let isAvailableOffline = filesAvailableOffline
            addAction = !isAvailableOffline
            if !isAvailableOffline {
                downloadInProgress = true
                collectionView.reloadItems(at: [indexPath])
                // Update offline files before setting new file to synchronize them
                (UIApplication.shared.delegate as? AppDelegate)?.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
            }
            for file in files where !file.isDirectory && file.isAvailableOffline == isAvailableOffline {
                group.enter()
                driveFileManager.setFileAvailableOffline(file: file, available: !isAvailableOffline) { error in
                    if error != nil {
                        self.success = false
                    }
                    if let file = self.driveFileManager.getCachedFile(id: file.id) {
                        self.changedFiles?.append(file)
                    }
                    group.leave()
                }
            }
        case .favorite:
            let isFavorite = filesAreFavorite
            addAction = !isFavorite
            group.enter()
            Task {
                do {
                    try await toggleFavorite(isFavorite: isFavorite)
                } catch {
                    success = false
                }
                group.leave()
            }
        case .folderColor:
            group.enter()
            if driveFileManager.drive.pack == .free {
                let driveFloatingPanelController = FolderColorFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController.contentViewController as? FolderColorFloatingPanelViewController
                floatingPanelViewController?.rightButton.isEnabled = driveFileManager.drive.accountAdmin
                floatingPanelViewController?.actionHandler = { _ in
                    driveFloatingPanelController.dismiss(animated: true) {
                        StorePresenter.showStore(from: self, driveFileManager: self.driveFileManager)
                    }
                }
                present(driveFloatingPanelController, animated: true)
            } else {
                let colorSelectionFloatingPanelViewController = ColorSelectionFloatingPanelViewController(files: files, driveFileManager: driveFileManager)
                let floatingPanelViewController = DriveFloatingPanelController()
                floatingPanelViewController.isRemovalInteractionEnabled = true
                floatingPanelViewController.set(contentViewController: colorSelectionFloatingPanelViewController)
                floatingPanelViewController.track(scrollView: colorSelectionFloatingPanelViewController.collectionView)
                colorSelectionFloatingPanelViewController.floatingPanelController = floatingPanelViewController
                colorSelectionFloatingPanelViewController.completionHandler = { isSuccess in
                    self.success = isSuccess
                    group.leave()
                }
                dismiss(animated: true) {
                    self.presentingParent?.present(floatingPanelViewController, animated: true)
                }
            }
        case .download:
            if files.count > Constants.bulkActionThreshold || allItemsSelected || files.contains(where: \.isDirectory) {
                if downloadInProgress,
                   let currentArchiveId = currentArchiveId,
                   let operation = DownloadQueue.instance.archiveOperationsInQueue[currentArchiveId] {
                    let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.cancelDownloadTitle, message: KDriveResourcesStrings.Localizable.cancelDownloadDescription, action: KDriveResourcesStrings.Localizable.buttonYes, destructive: true) {
                        operation.cancel()
                    }
                    present(alert, animated: true)
                    return
                } else {
                    downloadedArchiveUrl = nil
                    downloadInProgress = true
                    collectionView.reloadItems(at: [indexPath])
                    group.enter()
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
            } else {
                for file in files {
                    if file.isDownloaded {
                        save(file: file)
                    } else {
                        downloadInProgress = true
                        collectionView.reloadItems(at: [indexPath])
                        group.enter()
                        DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { [unowned self] _, error in
                            if error == nil {
                                DispatchQueue.main.async {
                                    save(file: file)
                                }
                            } else {
                                success = false
                            }
                            group.leave()
                        }
                        DownloadQueue.instance.addToQueue(file: file)
                    }
                }
            }
        case .duplicate:
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, disabledDirectoriesSelection: files.compactMap(\.parent)) { [files = files.map { $0.freezeIfNeeded() }] selectedDirectory in
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
        default:
            break
        }

        group.notify(queue: .main) {
            if self.success {
                if action == .offline && addAction {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListAddOfflineConfirmationSnackbar(self.files.filter { !$0.isDirectory }.count))
                } else if action == .favorite && addAction {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListAddFavorisConfirmationSnackbar(self.files.count))
                } else if action == .folderColor {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListColorFolderConfirmationSnackbar(self.files.filter(\.isDirectory).count))
                } else if action == .duplicate && addAction {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListDuplicationConfirmationSnackbar(self.files.count))
                }
            } else {
                if self.downloadError != .taskCancelled {
                    UIConstants.showSnackBar(message: self.downloadError?.localizedDescription ?? KDriveResourcesStrings.Localizable.errorGeneric)
                }
            }
            self.files = self.changedFiles ?? []
            self.downloadInProgress = false
            self.collectionView.reloadItems(at: [indexPath])
            if action == .download {
                if let downloadedArchiveUrl = self.downloadedArchiveUrl {
                    let documentExportViewController = UIDocumentPickerViewController(url: downloadedArchiveUrl, in: .exportToService)
                    self.present(documentExportViewController, animated: true)
                }
            } else {
                self.dismiss(animated: true)
            }
            self.reloadAction?()
            self.changedFiles = []
        }
    }

    override func track(action: FloatingPanelAction) {
        let numberOfFiles = files.count
        switch action {
        // Quick Actions
        case .duplicate:
            MatomoUtils.trackBulkEvent(eventWithCategory: .fileAction, name: "copy", numberOfItems: numberOfFiles)
        case .download:
            MatomoUtils.trackBulkEvent(eventWithCategory: .fileAction, name: "download", numberOfItems: numberOfFiles)
        case .favorite:
            MatomoUtils.trackBulkEvent(eventWithCategory: .fileAction, name: "add_favorite", numberOfItems: numberOfFiles)
        case .offline:
            MatomoUtils.trackBulkEvent(eventWithCategory: .fileAction, name: "set_offline", numberOfItems: numberOfFiles)
        case .delete:
            MatomoUtils.trackBulkEvent(eventWithCategory: .fileAction, name: "trash", numberOfItems: numberOfFiles)
        case .folderColor:
            MatomoUtils.trackBulkEvent(eventWithCategory: .fileAction, name: "color_folder", numberOfItems: numberOfFiles)
        default:
            break
        }
    }

    // MARK: - Private methods

    private func toggleFavorite(isFavorite: Bool) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in files where file.capabilities.canUseFavorite {
                group.addTask { [frozenFile = file.freezeIfNeeded()] in
                    try await self.driveFileManager.setFavorite(file: frozenFile, favorite: !isFavorite)
                    await MainActor.run {
                        if let file = self.driveFileManager.getCachedFile(id: file.id) {
                            self.changedFiles?.append(file)
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    @MainActor
    private func copy(files: [File], to selectedDirectory: File) async throws {
        if files.count > Constants.bulkActionThreshold || allItemsSelected {
            // addAction = false // Prevents the snackbar to be displayed
            let action: BulkAction
            if allItemsSelected {
                action = BulkAction(action: .copy, parentId: parentId, exceptFileIds: exceptFileIds, destinationDirectoryId: selectedDirectory.id)
            } else {
                action = BulkAction(action: .copy, fileIds: files.map(\.id), destinationDirectoryId: selectedDirectory.id)
            }
            let tabBarController = presentingViewController as? MainTabViewController
            let navigationController = tabBarController?.selectedViewController as? UINavigationController
            await (navigationController?.topViewController as? FileListViewController)?.viewModel.multipleSelectionViewModel?.performAndObserve(bulkAction: action)
        } else {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for file in files {
                    group.addTask {
                        _ = try await self.driveFileManager.apiFetcher.copy(file: file, to: selectedDirectory)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    private func downloadArchivedFiles(downloadCellPath: IndexPath, completion: @escaping (Result<URL, DriveError>) -> Void) {
        Task {
            do {
                let archiveBody: ArchiveBody
                if allItemsSelected, let parentId = parentId {
                    archiveBody = .init(parentId: parentId, exceptFileIds: exceptFileIds)
                } else {
                    archiveBody = .init(files: files)
                }
                let response = try await driveFileManager.apiFetcher.buildArchive(drive: driveFileManager.drive, body: archiveBody)
                self.currentArchiveId = response.id
                DownloadQueue.instance.observeArchiveDownloaded(self, archiveId: response.id) { _, archiveUrl, error in
                    if let archiveUrl = archiveUrl {
                        completion(.success(archiveUrl))
                    } else {
                        completion(.failure(error ?? .unknownError))
                    }
                }
                DownloadQueue.instance.addToQueue(archiveId: response.id, driveId: self.driveFileManager.drive.id)
                DispatchQueue.main.async {
                    self.collectionView.reloadItems(at: [downloadCellPath])
                }
            } catch {
                completion(.failure(error as? DriveError ?? .unknownError))
            }
        }
    }

    // MARK: - Collection view data source

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Self.sections[indexPath.section] {
        case .actions:
            let cell = collectionView.dequeueReusableCell(type: FloatingPanelActionCollectionViewCell.self, for: indexPath)
            let action = actions[indexPath.item]
            cell.configure(with: action, filesAreFavorite: filesAreFavorite, filesAvailableOffline: filesAvailableOffline, filesAreDirectory: files.allSatisfy(\.isDirectory), containsDirectory: files.contains(where: \.isDirectory), showProgress: downloadInProgress, archiveId: currentArchiveId)
            return cell
        default:
            return super.collectionView(collectionView, cellForItemAt: indexPath)
        }
    }
}
