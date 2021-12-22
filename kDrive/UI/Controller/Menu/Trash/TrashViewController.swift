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

class TrashViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "TrashViewController" }

    @IBOutlet weak var emptyTrashBarButtonItem: UIBarButtonItem!

    private var filesToRestore: [File] = []
    private var selectFolderViewController: TitleSizeAdjustingNavigationController!

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.trashTitle, emptyViewType: .noTrash)
        viewModel.sortType = .newerDelete
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
        }

        super.viewDidLoad()
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        guard driveFileManager != nil && currentDirectory != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
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

    override func getNewChanges() {
        // We don't have incremental changes for trash
        forceRefresh()
    }

    override func setUpHeaderView(_ headerView: FilesHeaderView, isListEmpty: Bool) {
        super.setUpHeaderView(headerView, isListEmpty: isListEmpty)
        // Hide move button in multiple selection
        headerView.selectView.moveButton.isHidden = true
        // Enable/disable empty trash button
        emptyTrashBarButtonItem.isEnabled = !isListEmpty
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
        if selectionMode {
            selectChild(at: indexPath)
            return
        }

        let file = viewModel.getFile(at: indexPath.item)
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
        let file = viewModel.getFile(at: indexPath.item)
        switch action {
        case .delete:
            deleteFiles([file])
        default:
            break
        }
    }

    // MARK: - Swipe action collection view data source

    override func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        if configuration.fromActivities || listStyle == .grid {
            return nil
        }
        return [.delete]
    }

    // MARK: - File cell delegate

    override func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let file = viewModel.getFile(at: indexPath.item)
        showFloatingPanel(files: [file])
    }

    // MARK: - Files header view delegate

    #if !ISEXTENSION
        override func deleteButtonPressed() {
            deleteFiles(Array(selectedItems))
        }

        override func menuButtonPressed() {
            showFloatingPanel(files: Array(selectedItems))
        }
    #endif
}

// MARK: - Trash options delegate

extension TrashViewController: TrashOptionsDelegate {
    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        switch option {
        case .restoreIn:
            filesToRestore = files
            selectFolderViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, delegate: self)
            present(selectFolderViewController, animated: true)
        case .restore:
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
                }
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
            }
        }
    }
}
