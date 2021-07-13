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
import UIKit

class TrashViewController: FileListViewController {
    override class var storyboard: UIStoryboard { Storyboard.menu }
    override class var storyboardIdentifier: String { "TrashViewController" }

    @IBOutlet weak var emptyTrashBarButtonItem: UIBarButtonItem!

    private var filesToRestore: [File] = []
    private var selectFolderViewController: TitleSizeAdjustingNavigationController!

    override func viewDidLoad() {
        // Set configuration
        configuration = Configuration(rootTitle: KDriveStrings.Localizable.trashTitle, emptyViewType: .noTrash)
        sortType = .newerDelete
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
        }

        super.viewDidLoad()
    }

    override func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
        }
        guard driveFileManager != nil && currentDirectory != nil else {
            DispatchQueue.main.async {
                completion(.success([]), false, true)
            }
            return
        }

        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            driveFileManager.apiFetcher.getTrashedFiles(driveId: driveFileManager.drive.id, page: page, sortType: sortType) { response, error in
                if let trashedList = response?.data {
                    completion(.success(trashedList), trashedList.count == DriveApiFetcher.itemPerPage, false)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, false)
                }
            }
        } else {
            driveFileManager.apiFetcher.getChildrenTrashedFiles(driveId: driveFileManager.drive.id, fileId: currentDirectory?.id, page: page, sortType: sortType) { response, error in
                if let file = response?.data {
                    let children = file.children
                    completion(.success(Array(children)), children.count == DriveApiFetcher.itemPerPage, false)
                } else {
                    completion(.failure(error ?? DriveError.localError), false, false)
                }
            }
        }
    }

    override func getNewChanges() {
        // We don't have incremental changes for trash
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
        let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalEmptyTrashTitle, message: KDriveStrings.Localizable.modalEmptyTrashDescription, action: KDriveStrings.Localizable.buttonEmpty, destructive: true, loading: true) { [self] in
            let group = DispatchGroup()
            var success = false
            group.enter()
            driveFileManager.apiFetcher.deleteAllFilesDefinitely(driveId: driveFileManager.drive.id) { _, error in
                if let error = error {
                    success = false
                    DDLogError("Error while emptying trash: \(error)")
                } else {
                    self.forceRefresh()
                    success = true
                }
                group.leave()
            }
            _ = group.wait(timeout: .now() + 5)
            DispatchQueue.main.async {
                let message = success ? KDriveStrings.Localizable.snackbarEmptyTrashConfirmation : KDriveStrings.Localizable.errorDelete
                UIConstants.showSnackBar(message: message, view: self.view)
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
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalDeleteDescription(files[0].name), boldText: files[0].name)
        } else {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalDeleteDescriptionPlural(files.count))
        }
        let alert = AlertTextViewController(title: KDriveStrings.Localizable.trashActionDelete, message: message, action: KDriveStrings.Localizable.buttonDelete, destructive: true, loading: true) {
            let group = DispatchGroup()
            var success = true
            for file in files {
                group.enter()
                self.driveFileManager.apiFetcher.deleteFileDefinitely(file: file) { _, error in
                    file.signalChanges(userId: self.driveFileManager.drive.userId)
                    if let error = error {
                        success = false
                        DDLogError("Error while deleting file: \(error)")
                    } else {
                        self.removeFileFromList(id: file.id)
                    }
                    group.leave()
                }
            }
            let result = group.wait(timeout: .now() + 5)
            if result == .timedOut {
                success = false
            }
            DispatchQueue.main.async {
                let message: String
                if success {
                    if files.count == 1 {
                        message = KDriveStrings.Localizable.snackbarDeleteConfirmation(files[0].name)
                    } else {
                        message = KDriveStrings.Localizable.snackbarDeleteConfirmationPlural(files.count)
                    }
                } else {
                    message = KDriveStrings.Localizable.errorDelete
                }
                UIConstants.showSnackBar(message: message, view: self.view)
                if self.selectionMode {
                    self.selectionMode = false
                }
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

        let file = sortedFiles[indexPath.row]
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
        let file = sortedFiles[indexPath.row]
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
        let file = sortedFiles[indexPath.row]
        showFloatingPanel(files: [file])
    }

    // MARK: - Files header view delegate

    #if !ISEXTENSION
        override func deleteButtonPressed() {
            deleteFiles(Array(selectedFiles))
        }

        override func menuButtonPressed() {
            showFloatingPanel(files: Array(selectedFiles))
        }
    #endif
}

// MARK: - Trash options delegate

extension TrashViewController: TrashOptionsDelegate {
    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        switch option {
        case .restoreIn:
            filesToRestore = files
            selectFolderViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
            selectFolderViewController.modalPresentationStyle = .fullScreen
            if let selectFolderVC = selectFolderViewController.topViewController as? SelectFolderViewController {
                selectFolderVC.delegate = self
            }
            present(selectFolderViewController, animated: true)
        case .restore:
            let group = DispatchGroup()
            for file in files {
                group.enter()
                driveFileManager.apiFetcher.restoreTrashedFile(file: file) { [self] _, error in
                    // TODO: Find parent to signal changes
                    file.signalChanges(userId: self.driveFileManager.drive.userId)
                    if error == nil {
                        removeFileFromList(id: file.id)
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.trashedFileRestoreFileToOriginalPlaceSuccess(file.name))
                    } else {
                        UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveStrings.Localizable.errorRestore)
                    }
                    group.leave()
                }
            }
            group.notify(queue: DispatchQueue.main) {
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
        let group = DispatchGroup()
        for file in filesToRestore {
            group.enter()
            driveFileManager.apiFetcher.restoreTrashedFile(file: file, in: folder.id) { [self] _, error in
                folder.signalChanges(userId: driveFileManager.drive.userId)
                if error == nil {
                    removeFileFromList(id: file.id)
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.trashedFileRestoreFileInSuccess(file.name, folder.name), view: self.view)
                } else {
                    UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveStrings.Localizable.errorRestore)
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            self.selectFolderViewController.dismiss(animated: true)
            if self.selectionMode {
                self.selectionMode = false
            }
        }
    }
}
