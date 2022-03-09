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
import kDriveCore
import kDriveResources
import UIKit

class MultipleSelectionFloatingPanelViewController: UICollectionViewController {
    var driveFileManager: DriveFileManager!
    var files: [File]!
    var changedFiles: [File]? = []
    var downloadInProgress = false
    var reloadAction: (() -> Void)?

    weak var presentingParent: UIViewController?

    var sharedWithMe: Bool {
        return driveFileManager?.drive.sharedWithMe ?? false
    }

    enum Section: CaseIterable {
        case actions
    }

    class var sections: [Section] {
        return [.actions]
    }

    var actions = FloatingPanelAction.listActions

    var filesAvailableOffline: Bool {
        return files.allSatisfy(\.isAvailableOffline)
    }

    var filesAreFavorite: Bool {
        return files.allSatisfy(\.isFavorite)
    }

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
        } else if files.count > Constants.bulkActionThreshold {
            actions = FloatingPanelAction.multipleSelectionBulkActions
        } else {
            actions = FloatingPanelAction.multipleSelectionActions
        }
    }

    func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        let action = actions[indexPath.row]
        var success = true
        var addAction = true
        var group = DispatchGroup()

        switch action {
        case .offline:
            group = FileActionsHelper.offline(files: files, at: indexPath, driveFileManager: driveFileManager) { indexPath in
                downloadInProgress = true
                collectionView.reloadItems(at: [indexPath])
                // Update offline files before setting new file to synchronize them
                (UIApplication.shared.delegate as? AppDelegate)?.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
            } completion: { file, error in
                if error != nil {
                    success = false
                }
                if let file = self.driveFileManager.getCachedFile(id: file.id) {
                    self.changedFiles?.append(file)
                }
            }
        case .favorite:
            group = FileActionsHelper.favorite(files: files, driveFileManager: driveFileManager) { file, isFavored, error in
                addAction = isFavored
                if error != nil {
                    success = false
                }
                if let file = self.driveFileManager.getCachedFile(id: file.id) {
                    self.changedFiles?.append(file)
                }
            }
        case .folderColor:
            group = FileActionsHelper.folderColor(files: files, driveFileManager: driveFileManager, with: self, presentingParent: presentingParent, completion: { isSuccess in
                success = isSuccess
            })
        case .download:
            if files.count > Constants.bulkActionThreshold || !files.allSatisfy({ !$0.isDirectory }) {
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
                    downloadArchivedFiles(files: files, downloadCellPath: indexPath) { archiveUrl, error in
                        self.downloadedArchiveUrl = archiveUrl
                        success = archiveUrl != nil
                        self.downloadError = error
                        group.leave()
                    }
                }
            } else {
                for file in files {
                    if file.isDownloaded {
                        FileActionsHelper.save(file: file, from: self)
                    } else {
                        downloadInProgress = true
                        collectionView.reloadItems(at: [indexPath])
                        group.enter()
                        DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { [unowned self] _, error in
                            if error == nil {
                                DispatchQueue.main.async {
                                    FileActionsHelper.save(file: file, from: self)
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
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, disabledDirectoriesSelection: files.compactMap(\.parent)) { [unowned self, fileIds = files.map(\.id)] selectedFolder in
                if self.files.count > Constants.bulkActionThreshold {
                    addAction = false // Prevents the snackbar to be displayed
                    let action = BulkAction(action: .copy, fileIds: fileIds, destinationDirectoryId: selectedFolder.id)
                    self.driveFileManager.apiFetcher.bulkAction(driveId: driveFileManager.drive.id, action: action) { response, error in
                        let tabBarController = presentingViewController as? MainTabViewController
                        let navigationController = tabBarController?.selectedViewController as? UINavigationController
                        (navigationController?.topViewController as? FileListViewController)?.bulkObservation(action: .copy, response: response, error: error)
                    }
                } else {
                    for file in self.files {
                        group.enter()
                        self.driveFileManager.apiFetcher.copyFile(file: file, newParent: selectedFolder) { _, error in
                            if error != nil {
                                success = false
                            }
                            group.leave()
                        }
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
            if success {
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
            self.files = self.changedFiles
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

    // MARK: - Private methods

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            switch sections[section] {
            case .actions:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(53))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
        }
    }

    private func downloadArchivedFiles(files: [File], downloadCellPath: IndexPath, completion: @escaping (URL?, DriveError?) -> Void) {
        driveFileManager.apiFetcher.getDownloadArchiveLink(driveId: driveFileManager.drive.id, for: files) { response, error in
            if let archiveId = response?.data?.uuid {
                self.currentArchiveId = archiveId
                DownloadQueue.instance.observeArchiveDownloaded(self, archiveId: archiveId) { _, archiveUrl, error in
                    completion(archiveUrl, error)
                }
                DownloadQueue.instance.addToQueue(archiveId: archiveId, driveId: self.driveFileManager.drive.id)
                DispatchQueue.main.async {
                    self.collectionView.reloadItems(at: [downloadCellPath])
                }
            } else {
                completion(nil, (error as? DriveError) ?? .serverError)
            }
        }
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action: FloatingPanelAction
        switch Self.sections[indexPath.section] {
        case .actions:
            action = actions[indexPath.item]
        }
        handleAction(action, at: indexPath)
        MatomoUtils.trackBulkAction(action: action, files: files, fromPhotoList: presentingParent is PhotoListViewController)
    }

    // MARK: - Collection view data source

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Self.sections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Self.sections[section] {
        case .actions:
            return actions.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Self.sections[indexPath.section] {
        case .actions:
            let cell = collectionView.dequeueReusableCell(type: FloatingPanelActionCollectionViewCell.self, for: indexPath)
            let action = actions[indexPath.item]
            cell.configure(with: action, filesAreFavorite: filesAreFavorite, filesAvailableOffline: filesAvailableOffline, filesAreDirectory: files.allSatisfy(\.isDirectory), containsDirectory: files.contains(where: \.isDirectory), showProgress: downloadInProgress, archiveId: currentArchiveId)
            return cell
        }
    }
}
