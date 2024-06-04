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
import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import Kingfisher
import RealmSwift
import UIKit

class TrashListViewModel: InMemoryFileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File? = nil) {
        let configuration = Configuration(selectAllSupported: false,
                                          rootTitle: KDriveResourcesStrings.Localizable.trashTitle,
                                          emptyViewType: currentDirectory == nil ? .noTrash : .emptyFolder,
                                          sortingOptions: [.nameAZ, .nameZA, .newerDelete, .olderDelete, .biggest, .smallest],
                                          matomoViewPath: [MatomoUtils.Views.menu.displayName, "TrashList"])
        super.init(configuration: configuration,
                   driveFileManager: driveFileManager,
                   currentDirectory: currentDirectory == nil ? DriveFileManager.trashRootFile : currentDirectory!)
        multipleSelectionViewModel = MultipleSelectionTrashViewModel(
            configuration: configuration,
            driveFileManager: driveFileManager,
            currentDirectory: self.currentDirectory
        )
    }

    override func startObservation() {
        super.startObservation()
        sortTypeObservation?.cancel()
        sortTypeObservation = nil
        sortType = .newerDelete
        sortingChanged()
    }

    override func sortingChanged() {
        files = AnyRealmCollection(files.sorted(by: [sortType.value.sortDescriptor]))
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) async throws {
        guard !isLoading || page > 1 else { return }

        startRefreshing(page: page)
        defer {
            endRefreshing()
        }

        let fetchedFiles: [File]
        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            fetchedFiles = try await driveFileManager.apiFetcher.trashedFiles(
                drive: driveFileManager.drive,
                page: page,
                sortType: sortType
            )
        } else {
            fetchedFiles = try await driveFileManager.apiFetcher.trashedFiles(
                of: currentDirectory.proxify(),
                page: page,
                sortType: sortType
            )
        }

        let moreComing = fetchedFiles.count == Endpoint.itemsPerPage
        addPage(files: fetchedFiles, fullyDownloaded: !moreComing, page: page)
        endRefreshing()

        if currentDirectory.id == DriveFileManager.trashRootFile.id {
            currentRightBarButtons = files.isEmpty ? nil : [.emptyTrash]
        }
        if moreComing {
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
                MatomoUtils.track(eventWithCategory: .trash, name: "emptyTrash")
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
            let message = success ? KDriveResourcesStrings.Localizable.snackbarEmptyTrashConfirmation : KDriveResourcesStrings
                .Localizable.errorDelete
            UIConstants.showSnackBar(message: message)
            if success {
                forceRefresh()
            }
        } catch {
            UIConstants.showSnackBarIfNeeded(error: error)
        }
    }

    override func didTapMore(at indexPath: IndexPath) {
        guard let file: File = getFile(at: indexPath) else { return }
        onPresentQuickActionPanel?([file], .trash)
    }

    override func didSelect(option: Selectable) {
        guard let type = option as? SortType else { return }
        sortType = type
        sortingChanged()
    }

    private func restoreTrashedFiles(
        _ restoredFiles: [ProxyFile],
        firstFilename: String,
        in directory: ProxyFile? = nil,
        directoryName: String? = nil
    ) async {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for file in restoredFiles {
                    group.addTask { [self] in
                        _ = try await driveFileManager.apiFetcher.restore(file: file, in: directory)
                        // We don't have an alert for moving multiple files, snackbar is spammed until end
                        if let directoryName {
                            await UIConstants
                                .showSnackBar(message: KDriveResourcesStrings.Localizable.trashedFileRestoreFileInSuccess(
                                    firstFilename,
                                    directoryName
                                ))

                        } else {
                            await UIConstants
                                .showSnackBar(message: KDriveResourcesStrings.Localizable
                                    .trashedFileRestoreFileToOriginalPlaceSuccess(firstFilename))
                        }
                    }
                }
                try await group.waitForAll()
            }
        } catch {
            UIConstants.showSnackBarIfNeeded(error: error)
        }
    }

    private func removeFilesAndDisableMultiSelection(_ deletedFiles: [ProxyFile]) {
        multipleSelectionViewModel?.isMultipleSelectionEnabled = false
        // TODO: Split code away from the ViewController, so it is not pinned to the main thread, and we can remove the .detached
        Task.detached { [weak self] in
            await self?.removeFiles(deletedFiles)
        }
    }
}

// MARK: - Trash options delegate

extension TrashListViewModel: TrashOptionsDelegate {
    func didClickOnTrashOption(option: TrashOption, files: [File]) {
        guard !files.isEmpty, let firstFilename = files.first?.name else { return }
        let proxyFiles = files.map { $0.proxify() }

        switch option {
        case .restoreIn:
            MatomoUtils.track(eventWithCategory: .trash, name: "restoreGivenFolder")
            let selectFolderNavigationViewController: TitleSizeAdjustingNavigationController
            selectFolderNavigationViewController = SelectFolderViewController
                .instantiateInNavigationController(driveFileManager: driveFileManager) { directory in
                    Task { [weak self, directoryProxy = directory.proxify(), directoryName = directory.name] in
                        await self?.restoreTrashedFiles(
                            proxyFiles,
                            firstFilename: firstFilename,
                            in: directoryProxy,
                            directoryName: directoryName
                        )
                        self?.removeFilesAndDisableMultiSelection(proxyFiles)
                    }
                }
            onPresentViewController?(.modal, selectFolderNavigationViewController, true)
        case .restore:
            MatomoUtils.track(eventWithCategory: .trash, name: "restoreOriginFolder")
            Task { [weak self] in
                await self?.restoreTrashedFiles(proxyFiles, firstFilename: firstFilename)
                self?.removeFilesAndDisableMultiSelection(proxyFiles)
            }
        case .delete:
            let alert = TrashViewModelHelper.deleteAlertForFiles(
                proxyFiles,
                firstFilename: firstFilename,
                driveFileManager: driveFileManager
            ) { [weak self] _ in
                MatomoUtils.track(eventWithCategory: .trash, name: "deleteFromTrash")
                Task { [weak self] in
                    self?.removeFilesAndDisableMultiSelection(proxyFiles)
                }
            }
            onPresentViewController?(.modal, alert, true)
        }
    }
}

private enum TrashViewModelHelper {
    static func deleteAlertForFiles(
        _ files: [ProxyFile],
        firstFilename: String,
        driveFileManager: DriveFileManager,
        completion: @MainActor @escaping ([ProxyFile]) -> Void
    ) -> AlertTextViewController {
        let message: NSMutableAttributedString
        if files.count == 1 {
            message = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable.modalDeleteDescription(firstFilename),
                boldText: firstFilename
            )
        } else {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable
                .modalDeleteDescriptionPlural(files.count))
        }

        return AlertTextViewController(title: KDriveResourcesStrings.Localizable.trashActionDelete,
                                       message: message,
                                       action: KDriveResourcesStrings.Localizable.buttonDelete,
                                       destructive: true, loading: true) {
            let files = await deleteFiles(files, firstFilename: firstFilename, driveFileManager: driveFileManager)
            await completion(files)
        }
    }

    private static func deleteFiles(_ deletedFiles: [ProxyFile], firstFilename: String,
                                    driveFileManager: DriveFileManager) async -> [ProxyFile] {
        do {
            let definitelyDeletedFiles = try await withThrowingTaskGroup(of: ProxyFile.self) { group -> [ProxyFile] in
                for file in deletedFiles {
                    group.addTask {
                        _ = try await driveFileManager.apiFetcher.deleteDefinitely(file: file)
                        return file
                    }
                }

                var successFullyDeletedFile = [ProxyFile]()
                for try await file in group {
                    successFullyDeletedFile.append(file)
                }
                return successFullyDeletedFile
            }

            await UIConstants
                .showSnackBar(message: KDriveResourcesStrings.Localizable
                    .trashedFileDeletedPermanentlyConfirmationSnackbar(definitelyDeletedFiles.count))
            return definitelyDeletedFiles
        } catch {
            await UIConstants.showSnackBarIfNeeded(error: error)
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
            guard let firstSelectedItem = selectedItems.first,
                  let realmConfiguration = firstSelectedItem.realm?.configuration else { return }
            let selectedItemCount = selectedItems.count
            let alert = TrashViewModelHelper.deleteAlertForFiles(selectedItems.map { $0.proxify() },
                                                                 firstFilename: firstSelectedItem.name,
                                                                 driveFileManager: driveFileManager) { [weak self] deletedFiles in
                MatomoUtils.trackBulkEvent(eventWithCategory: .trash, name: "DeleteFromTrash", numberOfItems: selectedItemCount)
                self?.removeFromRealm(realmConfiguration, deletedFiles: deletedFiles)

                // quickwin for privacy, remove all image cache after a permanent clean
                try? ImageCache.default.diskStorage.removeAll()
                ImageCache.default.memoryStorage.removeAll()
            }
            onPresentViewController?(.modal, alert, true)
        case .more:
            onPresentQuickActionPanel?(Array(selectedItems), .trash)
        default:
            break
        }
    }

    private func removeFromRealm(_ realmConfiguration: Realm.Configuration, deletedFiles: [ProxyFile]) {
        Task {
            isMultipleSelectionEnabled = false
            guard let realm = try? Realm(configuration: realmConfiguration) else { return }
            try? realm.write {
                for file in deletedFiles {
                    if let file = realm.object(ofType: File.self, forPrimaryKey: file.id), !file.isInvalidated {
                        realm.delete(file)
                    }
                }
            }
        }
    }
}
