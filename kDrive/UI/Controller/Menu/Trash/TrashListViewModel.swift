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
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        var configuration = Configuration(selectAllSupported: false, rootTitle: KDriveResourcesStrings.Localizable.trashTitle, emptyViewType: .noTrash, sortingOptions: [.nameAZ, .nameZA, .newerDelete, .olderDelete, .biggest, .smallest])
        var currentDirectory = currentDirectory
        if currentDirectory == nil {
            currentDirectory = DriveFileManager.trashRootFile
            configuration.rightBarButtons = [.emptyTrash]
        }
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory!)
        sortTypeObservation?.cancel()
        sortTypeObservation = nil
        sortType = .newerDelete
        multipleSelectionViewModel = MultipleSelectionTrashViewModel(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: self.currentDirectory)
    }

    private func handleNewChildren(_ children: [File]?, page: Int, error: Error?) {
        isLoading = false
        isRefreshIndicatorHidden = true

        if let children = children {
            let startIndex = fileCount
            files.append(contentsOf: children)
            onFileListUpdated?([], Array(startIndex ..< files.count), [], files.isEmpty, false)
            if children.count == DriveApiFetcher.itemPerPage {
                loadFiles(page: page + 1)
            }
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

        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            driveFileManager.apiFetcher.getTrashedFiles(driveId: driveFileManager.drive.id, page: page, sortType: sortType) { [weak self] response, error in
                self?.handleNewChildren(response?.data, page: page, error: error)
            }
        } else {
            driveFileManager.apiFetcher.getChildrenTrashedFiles(driveId: driveFileManager.drive.id, fileId: currentDirectory.id, page: page, sortType: sortType) { [weak self] response, error in
                var children: [File]?
                if let fetchedChildren = response?.data?.children {
                    children = Array(fetchedChildren)
                }
                self?.handleNewChildren(children, page: page, error: error)
            }
        }
    }

    override func loadActivities() {
        forceRefresh()
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .emptyTrash {
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalEmptyTrashTitle,
                                                message: KDriveResourcesStrings.Localizable.modalEmptyTrashDescription,
                                                action: KDriveResourcesStrings.Localizable.buttonEmpty,
                                                destructive: true, loading: true) { [self] in
                emptyTrashSync()
                forceRefresh()
            }
            onPresentViewController?(.modal, alert, true)
        } else {
            super.barButtonPressed(type: type)
        }
    }

    override func didSelectSwipeAction(_ action: SwipeCellAction, at index: Int) {
        if let file = getFile(at: index),
           action == .delete {
            didClickOnTrashOption(option: .delete, files: [file])
        }
    }

    override func getSwipeActions(at index: Int) -> [SwipeCellAction]? {
        if configuration.fromActivities || listStyle == .grid {
            return nil
        }
        return [.delete]
    }

    private func emptyTrashSync() {
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
        _ = group.wait(timeout: .now() + Constants.timeout)

        DispatchQueue.main.async {
            let message = success ? KDriveResourcesStrings.Localizable.snackbarEmptyTrashConfirmation : KDriveResourcesStrings.Localizable.errorDelete
            UIConstants.showSnackBar(message: message)
        }
    }

    override func didTapMore(at index: Int) {
        guard let file: File = getFile(at: index) else { return }
        onPresentQuickActionPanel?([file], .trash)
    }

    private func restoreTrashedFiles(_ restoredFiles: [File], in directory: File, completion: @escaping () -> Void) {
        let group = DispatchGroup()
        for file in restoredFiles {
            group.enter()
            driveFileManager.apiFetcher.restoreTrashedFile(file: file, in: directory.id) { [self] _, error in
                directory.signalChanges(userId: driveFileManager.drive.userId)
                if error == nil {
                    driveFileManager.notifyObserversWith(file: DriveFileManager.trashRootFile)
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileInSuccess(file.name, directory.name))
                } else {
                    UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveResourcesStrings.Localizable.errorRestore)
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            self.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
            completion()
        }
    }

    private func restoreTrashedFiles(_ restoredFiles: [File]) {
        let group = DispatchGroup()
        for file in restoredFiles {
            group.enter()
            driveFileManager.apiFetcher.restoreTrashedFile(file: file) { [self] _, error in
                if error == nil {
                    driveFileManager.notifyObserversWith(file: DriveFileManager.trashRootFile)
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileToOriginalPlaceSuccess(file.name))
                } else {
                    UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveResourcesStrings.Localizable.errorRestore)
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            self.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
        }
    }
}

// MARK: - Trash options delegate

extension TrashListViewModel: TrashOptionsDelegate {
    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        switch option {
        case .restoreIn:
            var selectFolderNavigationViewController: TitleSizeAdjustingNavigationController!
            selectFolderNavigationViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager) { directory in
                self.restoreTrashedFiles(files, in: directory) {
                    selectFolderNavigationViewController?.dismiss(animated: true)
                }
            }
            onPresentViewController?(.modal, selectFolderNavigationViewController, true)
        case .restore:
            restoreTrashedFiles(files)
        case .delete:
            let alert = TrashViewModelHelper.deleteAlertForFiles(files, driveFileManager: driveFileManager) { [weak self] deletedFiles in
                deletedFiles.forEach { self?.removeFile(file: $0) }
                self?.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
            }
            onPresentViewController?(.modal, alert, true)
        }
    }
}

private enum TrashViewModelHelper {
    static func deleteAlertForFiles(_ files: [File], driveFileManager: DriveFileManager, completion: @escaping ([File]) -> Void) -> AlertTextViewController {
        let message: NSMutableAttributedString
        if files.count == 1,
           let firstFile = files.first {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalDeleteDescription(firstFile.name), boldText: firstFile.name)
        } else {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalDeleteDescriptionPlural(files.count))
        }

        return AlertTextViewController(title: KDriveResourcesStrings.Localizable.trashActionDelete,
                                       message: message,
                                       action: KDriveResourcesStrings.Localizable.buttonDelete,
                                       destructive: true, loading: true) {
            deleteFiles(files, driveFileManager: driveFileManager, completion: completion)
        }
    }

    private static func deleteFiles(_ files: [File], driveFileManager: DriveFileManager, completion: @escaping ([File]) -> Void) {
        let group = DispatchGroup()
        var success = true
        var deletedFiles = [File]()
        for file in files {
            group.enter()
            driveFileManager.apiFetcher.deleteFileDefinitely(file: file) { _, error in
                file.signalChanges(userId: driveFileManager.drive.userId)
                if let error = error {
                    success = false
                    DDLogError("Error while deleting file: \(error)")
                } else {
                    deletedFiles.append(file)
                }
                group.leave()
            }
        }
        group.notify(queue: DispatchQueue.main) {
            let message: String
            if success {
                if files.count == 1 {
                    message = KDriveResourcesStrings.Localizable.snackbarDeleteConfirmation(files[0].name)
                } else {
                    message = KDriveResourcesStrings.Localizable.snackbarDeleteConfirmationPlural(deletedFiles.count)
                }
            } else {
                message = KDriveResourcesStrings.Localizable.errorDelete
            }
            UIConstants.showSnackBar(message: message)
            completion(deletedFiles)
        }
    }
}

class MultipleSelectionTrashViewModel: MultipleSelectionFileListViewModel {
    override init(configuration: FileListViewModel.Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        multipleSelectionActions = [.deletePermanently, .more]
    }

    override func actionButtonPressed(action: MultipleSelectionAction) {
        switch action {
        case .deletePermanently:
            let alert = TrashViewModelHelper.deleteAlertForFiles(Array(selectedItems), driveFileManager: driveFileManager) { [weak self] _ in
                self?.driveFileManager.notifyObserversWith(file: DriveFileManager.trashRootFile)
                self?.isMultipleSelectionEnabled = false
            }
            onPresentViewController?(.modal, alert, true)
        case .more:
            onPresentQuickActionPanel?(Array(selectedItems), .trash)
        default:
            break
        }
    }
}
