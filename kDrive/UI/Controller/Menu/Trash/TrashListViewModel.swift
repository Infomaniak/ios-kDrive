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

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard !isLoading || page > 1 else { return }

        startRefreshing(page: page)
        defer {
            endRefreshing()
        }

        let fetchedFiles: [File]
        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            fetchedFiles = try await driveFileManager.apiFetcher.trashedFiles(drive: driveFileManager.drive, page: page, sortType: sortType)
        } else {
            fetchedFiles = try await driveFileManager.apiFetcher.trashedFiles(of: currentDirectory, page: page, sortType: sortType)
        }

        let startIndex = fileCount
        files.append(contentsOf: fetchedFiles)
        onFileListUpdated?([], Array(startIndex ..< files.count), [], files.isEmpty, false)
        endRefreshing()
        if files.count == Endpoint.itemsPerPage {
            try await loadFiles(page: page + 1)
        }
    }

    override func loadActivities() async throws {
        forceRefresh()
    }

    override func barButtonPressed(type: FileListBarButtonType) {
        if type == .emptyTrash {
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalEmptyTrashTitle,
                                                message: KDriveResourcesStrings.Localizable.modalEmptyTrashDescription,
                                                action: KDriveResourcesStrings.Localizable.buttonEmpty,
                                                destructive: true, loading: true) { [self] in
                await emptyTrash()
            }
            onPresentViewController?(.modal, alert, true)
        } else {
            super.barButtonPressed(type: type)
        }
    }

    override func didSelectSwipeAction(_ action: SwipeCellAction, at indexPath: IndexPath) {
        if let file = getFile(at: indexPath),
           action == .delete {
            didClickOnTrashOption(option: .delete, files: [file])
        }
    }

    override func getSwipeActions(at indexPath: IndexPath) -> [SwipeCellAction]? {
        if configuration.fromActivities || listStyle == .grid {
            return nil
        }
        return [.delete]
    }

    private func emptyTrash() async {
        do {
            let success = try await driveFileManager.apiFetcher.emptyTrash(drive: driveFileManager.drive)
            let message = success ? KDriveResourcesStrings.Localizable.snackbarEmptyTrashConfirmation : KDriveResourcesStrings.Localizable.errorDelete
            UIConstants.showSnackBar(message: message)
            if success {
                forceRefresh()
            }
        } catch {
            UIConstants.showSnackBar(message: error.localizedDescription)
        }
    }

    override func didTapMore(at indexPath: IndexPath) {
        guard let file: File = getFile(at: indexPath) else { return }
        onPresentQuickActionPanel?([file], .trash)
    }

    private func restoreTrashedFiles(_ restoredFiles: [File], in directory: File? = nil) async {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for file in restoredFiles {
                    group.addTask { [self] in
                        _ = try await driveFileManager.apiFetcher.restore(file: file, in: directory)
                        // TODO: We don't have an alert for moving multiple files, snackbar is spammed until end
                        if let directory = directory {
                            _ = await MainActor.run {
                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileInSuccess(file.name, directory.name))
                            }
                        } else {
                            _ = await MainActor.run {
                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileToOriginalPlaceSuccess(file.name))
                            }
                        }
                    }
                }
                try await group.waitForAll()
            }
            directory?.signalChanges(userId: driveFileManager.drive.userId)

        } catch {
            UIConstants.showSnackBar(message: error.localizedDescription)
        }
        multipleSelectionViewModel?.isMultipleSelectionEnabled = false
    }
}

// MARK: - Trash options delegate

extension TrashListViewModel: TrashOptionsDelegate {
    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        switch option {
        case .restoreIn:
            let selectFolderNavigationViewController: TitleSizeAdjustingNavigationController
            selectFolderNavigationViewController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager) { [self] directory in
                Task {
                    await restoreTrashedFiles(files, in: directory)
                }
            }
            onPresentViewController?(.modal, selectFolderNavigationViewController, true)
        case .restore:
            Task {
                await restoreTrashedFiles(files)
            }
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
            let files = await deleteFiles(files, driveFileManager: driveFileManager, completion: completion)
            completion(files)
        }
    }

    private static func deleteFiles(_ deletedFiles: [File], driveFileManager: DriveFileManager, completion: @escaping ([File]) -> Void) async -> [File] {
        do {
            let definitelyDeletedFiles = try await withThrowingTaskGroup(of: File.self) { group -> [File] in
                for file in deletedFiles {
                    group.addTask {
                        _ = try await driveFileManager.apiFetcher.deleteDefinitely(file: file)
                        file.signalChanges(userId: driveFileManager.drive.userId)
                        return file
                    }
                }

                var successFullyDeletedFile = [File]()
                for try await file in group {
                    successFullyDeletedFile.append(file)
                }
                return successFullyDeletedFile
            }

            let message: String
            if definitelyDeletedFiles.count == 1 {
                message = KDriveResourcesStrings.Localizable.snackbarDeleteConfirmation(definitelyDeletedFiles[0].name)
            } else {
                message = KDriveResourcesStrings.Localizable.snackbarDeleteConfirmationPlural(definitelyDeletedFiles.count)
            }

            UIConstants.showSnackBar(message: message)
            return definitelyDeletedFiles
        } catch {
            UIConstants.showSnackBar(message: error.localizedDescription)
            return []
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
