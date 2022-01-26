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
import kDriveCore
import kDriveResources
import UIKit

class TrashListViewModel: UnmanagedFileListViewModel {
    init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        var configuration = FileListViewController.Configuration(selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.trashTitle, emptyViewType: .noTrash)
        var currentDirectory = currentDirectory
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
            configuration.rightBarButtons = [.emptyTrash]
        }
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        sortTypeObservation?.cancel()
        sortTypeObservation = nil
        sortType = .newerDelete
    }

    private func handleNewChildren(_ children: [File]?, page: Int, error: Error?) {
        isLoading = false
        isRefreshIndicatorHidden = true

        if let children = children {
            let startIndex = fileCount
            files.append(contentsOf: children)
            onFileListUpdated?([], Array(startIndex ..< files.count), [], false)
            if children.count == DriveApiFetcher.itemPerPage {
                loadFiles(page: page + 1)
            }
            isEmptyViewHidden = fileCount > 0
        } else {
            onDriveError?((error as? DriveError) ?? DriveError.localError)
        }
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) {
        guard !isLoading || page > 1 else { return }

        isLoading = true
        if page == 1 {
            showLoadingIndicatorIfNeeded()
        }

        Task {
            do {
                let files: [File]
                if currentDirectory.id == DriveFileManager.trashRootFile.id {
                    files = try await driveFileManager.apiFetcher.trashedFiles(drive: driveFileManager.drive, page: page, sortType: sortType)
                } else {
                    files = try await driveFileManager.apiFetcher.trashedFiles(of: currentDirectory, page: page, sortType: sortType)
                }
                completion(.success(Array(files)), files.count == Endpoint.itemsPerPage, false)
            } catch {
                completion(.failure(error), false, false)
            }
        }
    }

    override func loadActivities() {
        forceRefresh()
    }
}

class TrashViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "TrashViewController" }

    @IBOutlet weak var emptyTrashBarButtonItem: UIBarButtonItem!

    private var filesToRestore: [File] = []
    private var selectFolderViewController: TitleSizeAdjustingNavigationController!

    override func getViewModel() -> FileListViewModel {
        return TrashListViewModel(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
    }

    // MARK: - Actions

    @IBAction func emptyTrash(_ sender: UIBarButtonItem) {
        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalEmptyTrashTitle, message: KDriveResourcesStrings.Localizable.modalEmptyTrashDescription, action: KDriveResourcesStrings.Localizable.buttonEmpty, destructive: true, loading: true) { [self] in
            do {
                let response = try await driveFileManager.apiFetcher.emptyTrash(drive: driveFileManager.drive)
                if response {
                    forceRefresh()
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarEmptyTrashConfirmation)
                } else {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDelete)
                }
            } catch {
                DDLogError("Error while emptying trash: \(error)")
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            MatomoUtils.track(eventWithCategory: .trash, name: "emptyTrash")
        }
        present(alert, animated: true)
    }

    // MARK: - Private methods

    private func showFloatingPanel(files: [File]) {
        let floatingPanelViewController = DriveFloatingPanelController()
        let trashFloatingPanelTableViewController = TrashFloatingPanelTableViewController()
        floatingPanelViewController.isRemovalInteractionEnabled = true
        trashFloatingPanelTableViewController.delegate = self
        trashFloatingPanelTableViewController.trashedFiles = files
        floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 200)

        floatingPanelViewController.set(contentViewController: trashFloatingPanelTableViewController)
        present(floatingPanelViewController, animated: true)
    }

    private func deleteFiles(_ files: [File]) {
        let message: NSMutableAttributedString
        if files.count == 1 {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalDeleteDescription(files[0].name), boldText: files[0].name)
        } else {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalDeleteDescriptionPlural(files.count))
        }
        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.trashActionDelete, message: message, action: KDriveResourcesStrings.Localizable.buttonDelete, destructive: true, loading: true) {
            if self.selectionMode {
                MatomoUtils.trackBulkEvent(eventWithCategory: .trash, name: "deleteFromTrash", numberOfItems: self.selectedItems.count)
            } else {
                MatomoUtils.track(eventWithCategory: .trash, name: "deleteFromTrash")
            }
            do {
                let success = try await withThrowingTaskGroup(of: Bool.self, returning: Bool.self) { group in
                    for file in files {
                        group.addTask {
                            let response = try await self.driveFileManager.apiFetcher.deleteDefinitely(file: file)
                            if response {
                                await file.signalChanges(userId: self.driveFileManager.drive.userId)
                                await self.removeFileFromList(id: file.id)
                            }
                            return response
                        }
                    }
                    return try await group.allSatisfy { $0 }
                }
                let message: String
                if success {
                    if files.count == 1 {
                        message = KDriveResourcesStrings.Localizable.snackbarDeleteConfirmation(files[0].name)
                    } else {
                        message = KDriveResourcesStrings.Localizable.snackbarDeleteConfirmationPlural(files.count)
                    }
                } else {
                    message = KDriveResourcesStrings.Localizable.errorDelete
                }
                UIConstants.showSnackBar(message: message)
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            if self.selectionMode {
                self.selectionMode = false
            }
        }
        present(alert, animated: true)
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        /* if selectionMode {
             selectChild(at: indexPath)
             return
         } */
        let file = viewModel.getFile(at: indexPath.item)!
        if file.isDirectory {
            let trashCV = TrashViewController.instantiate(driveFileManager: driveFileManager)
            trashCV.currentDirectory = file
            navigationController?.pushViewController(trashCV, animated: true)
        } else {
            showFloatingPanel(files: [file])
        }
    }

    // MARK: - Swipe action collection view delegate

    override func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        let file = viewModel.getFile(at: indexPath.item)!
        switch action {
        case .delete:
            deleteFiles([file])
        default:
            break
        }
    }

    // MARK: - Swipe action collection view data source

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if viewModel.configuration.fromActivities || viewModel.listStyle == .grid {
            return nil
        }
        return [.delete]
    }

    // MARK: - File cell delegate

    override func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let file = viewModel.getFile(at: indexPath.item)!
        showFloatingPanel(files: [file])
    }
}

// MARK: - Trash options delegate

extension TrashViewController: TrashOptionsDelegate {
    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        switch option {
        case .restoreIn:
            MatomoUtils.track(eventWithCategory: .trash, name: "restoreGivenFolder")
            filesToRestore = files
            selectFolderViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, delegate: self)
            present(selectFolderViewController, animated: true)
        case .restore:
            MatomoUtils.track(eventWithCategory: .trash, name: "restoreOriginFolder")
            Task {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for file in files {
                            group.addTask {
                                _ = try await self.driveFileManager.apiFetcher.restore(file: file)
                                // TODO: Find parent to signal changes
                                await file.signalChanges(userId: self.driveFileManager.drive.userId)
                                await self.removeFileFromList(id: file.id)
                                _ = await MainActor.run {
                                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileToOriginalPlaceSuccess(file.name))
                                }
                            }
                        }
                        try await group.waitForAll()
                    }
                } catch {
                    UIConstants.showSnackBar(message: error.localizedDescription)
                }
                if self.selectionMode {
                    self.selectionMode = false
                }*/
            }
        case .delete:
            deleteFiles(files)
        }
    }
}

// MARK: - Select folder delegate

extension TrashViewController: SelectFolderDelegate {
    func didSelectFolder(_ folder: File) {
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for file in filesToRestore {
                        group.addTask {
                            _ = try await self.driveFileManager.apiFetcher.restore(file: file, in: folder)
                            await folder.signalChanges(userId: self.driveFileManager.drive.userId)
                            await self.removeFileFromList(id: file.id)
                            _ = await MainActor.run {
                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileInSuccess(file.name, folder.name))
                            }
                        }
                    }
                    try await group.waitForAll()
                }
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            if self.selectionMode {
                self.selectionMode = false
            }*/
        }
    }
}
