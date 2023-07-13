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

import CocoaLumberjackSwift
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class MultipleSelectionFloatingPanelViewController: UICollectionViewController {
    @LazyInjectService var accountManager: AccountManageable

    var driveFileManager: DriveFileManager!
    var files = [File]()
    var allItemsSelected = false
    var exceptFileIds: [Int]?
    var currentDirectory: File!
    var changedFiles: [File]? = []
    var downloadInProgress = false
    var reloadAction: (() -> Void)?

    weak var presentingParent: UIViewController?

    var sharedWithMe: Bool {
        return driveFileManager?.drive.sharedWithMe ?? false
    }

    var actions = FloatingPanelAction.listActions

    private var addAction = true
    private var success = true
    private var downloadedArchiveUrl: URL?
    private var currentArchiveId: String?
    private var downloadError: DriveError?

    convenience init() {
        self.init(collectionViewLayout: MultipleSelectionFloatingPanelViewController.createLayout())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(cellView: FloatingPanelActionCollectionViewCell.self)
        collectionView.alwaysBounceVertical = false
        setupContent()
    }

    func setupContent() {
        if sharedWithMe {
            actions = FloatingPanelAction.multipleSelectionSharedWithMeActions
        } else if allItemsSelected {
            actions = FloatingPanelAction.selectAllActions
        } else if files.count > Constants.bulkActionThreshold || allItemsSelected {
            actions = FloatingPanelAction.multipleSelectionBulkActions
            if files.contains(where: { $0.parentId != files.first?.parentId }) {
                actions.removeAll { $0 == .download }
            }
        } else {
            actions = FloatingPanelAction.multipleSelectionActions
        }
    }

    func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        let action = actions[indexPath.row]
        success = true
        addAction = true
        let group = DispatchGroup()

        switch action {
        case .offline:
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
        case .favorite:
            group.enter()
            Task {
                let isFavored = try await FileActionsHelper.favorite(files: files,
                                                                     driveFileManager: driveFileManager,
                                                                     completion: favorite)
                addAction = isFavored
                group.leave()
            }
        case .manageCategories:
            FileActionsHelper.manageCategories(files: files,
                                               driveFileManager: driveFileManager,
                                               from: self,
                                               group: group,
                                               presentingParent: presentingParent)
        case .folderColor:
            FileActionsHelper.folderColor(files: files,
                                          driveFileManager: driveFileManager,
                                          from: self,
                                          presentingParent: presentingParent,
                                          group: group) { isSuccess in
                self.success = isSuccess
            }
        case .download:
            if !allItemsSelected &&
                (files.allSatisfy { $0.convertedType == .image || $0.convertedType == .video } || files.count <= 1) {
                for file in files {
                    if file.isDownloaded {
                        FileActionsHelper.save(file: file, from: self, showSuccessSnackBar: false)
                    } else {
                        guard let observerViewController = view.window?.rootViewController else { return }
                        downloadInProgress = true
                        collectionView.reloadItems(at: [indexPath])
                        group.enter()
                        DownloadQueue.instance
                            .observeFileDownloaded(observerViewController, fileId: file.id) { [unowned self] _, error in
                                if error == nil {
                                    DispatchQueue.main.async {
                                        FileActionsHelper.save(file: file, from: self, showSuccessSnackBar: false)
                                    }
                                } else {
                                    success = false
                                }
                                group.leave()
                            }
                        DownloadQueue.instance.addToQueue(file: file, userId: accountManager.currentUserId)
                    }
                }
            } else {
                if downloadInProgress,
                   let currentArchiveId,
                   let operation = DownloadQueue.instance.archiveOperationsInQueue[currentArchiveId] {
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
        case .move:
            FileActionsHelper.move(files: files,
                                   exceptFileIds: exceptFileIds ?? [],
                                   from: currentDirectory,
                                   allItemsSelected: allItemsSelected,
                                   observer: self,
                                   driveFileManager: driveFileManager) { [weak self] viewController in
                dismiss(animated: true) {
                    self?.presentingParent?.present(viewController, animated: true)
                }
            }
        case .duplicate:
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
        default:
            break
        }

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
                        : (UIApplication.shared.delegate as! AppDelegate).topMostViewController
                    guard viewController as? UIDocumentPickerViewController == nil else { return }
                    let documentExportViewController = UIDocumentPickerViewController(
                        url: downloadedArchiveUrl,
                        in: .exportToService
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

    // MARK: - Private methods

    @MainActor
    private func copy(files: [File], to selectedDirectory: File) async throws {
        if files.count > Constants.bulkActionThreshold || allItemsSelected {
            // addAction = false // Prevents the snackbar to be displayed
            let action: BulkAction
            if allItemsSelected {
                action = BulkAction(
                    action: .copy,
                    parentId: currentDirectory.id,
                    exceptFileIds: exceptFileIds,
                    destinationDirectoryId: selectedDirectory.id
                )
            } else {
                action = BulkAction(action: .copy, fileIds: files.map(\.id), destinationDirectoryId: selectedDirectory.id)
            }
            let tabBarController = presentingViewController as? MainTabViewController
            let navigationController = tabBarController?.selectedViewController as? UINavigationController
            await (navigationController?.topViewController as? FileListViewController)?.viewModel.multipleSelectionViewModel?
                .performAndObserve(bulkAction: action)
        } else {
            // MainActor should ensure that this call is safe as file was created on the main thread ?
            let proxyFiles = files.map { $0.proxify() }
            let proxySelectedDirectory = selectedDirectory.proxify()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for proxyFile in proxyFiles {
                    group.addTask {
                        _ = try await self.driveFileManager.apiFetcher.copy(file: proxyFile, to: proxySelectedDirectory)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    private func downloadArchivedFiles(downloadCellPath: IndexPath, completion: @escaping (Result<URL, DriveError>) -> Void) {
        Task { [proxyFiles = files.map { $0.proxify() }, currentProxyDirectory = currentDirectory.proxify()] in
            do {
                let archiveBody: ArchiveBody
                if allItemsSelected {
                    archiveBody = .init(parentId: currentProxyDirectory.id, exceptFileIds: exceptFileIds)
                } else {
                    archiveBody = .init(files: proxyFiles)
                }
                let response = try await driveFileManager.apiFetcher.buildArchive(
                    drive: driveFileManager.drive,
                    body: archiveBody
                )
                currentArchiveId = response.uuid
                guard let rootViewController = view.window?.rootViewController else { return }
                DownloadQueue.instance
                    .observeArchiveDownloaded(rootViewController, archiveId: response.uuid) { _, archiveUrl, error in
                        if let archiveUrl {
                            completion(.success(archiveUrl))
                        } else {
                            completion(.failure(error ?? .unknownError))
                        }
                    }
                DownloadQueue.instance.addToQueue(archiveId: response.uuid,
                                                  driveId: self.driveFileManager.drive.id,
                                                  userId: accountManager.currentUserId)
                self.collectionView.reloadItems(at: [downloadCellPath])
            } catch {
                completion(.failure(error as? DriveError ?? .unknownError))
            }
        }
    }

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(53))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            return NSCollectionLayoutSection(group: group)
        }
    }

    private func favorite(file: File) async {
        if let file = driveFileManager.getCachedFile(id: file.id) {
            await MainActor.run {
                self.changedFiles?.append(file)
            }
        }
    }

    // MARK: - Collection view

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: FloatingPanelActionCollectionViewCell.self, for: indexPath)
        let action = actions[indexPath.item]
        cell.configure(with: action, files: files, showProgress: downloadInProgress, archiveId: currentArchiveId)
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = actions[indexPath.item]
        handleAction(action, at: indexPath)
        MatomoUtils.trackBuklAction(action: action, files: files, fromPhotoList: presentingParent is PhotoListViewController)
    }
}
