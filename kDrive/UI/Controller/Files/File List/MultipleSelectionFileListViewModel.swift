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
import Foundation
import kDriveCore
import kDriveResources

struct MultipleSelectionAction: Equatable {
    let id: Int
    let name: String
    let icon: KDriveResourcesImages
    var enabled = true

    static func == (lhs: MultipleSelectionAction, rhs: MultipleSelectionAction) -> Bool {
        return lhs.id == rhs.id
    }

    static let move = MultipleSelectionAction(id: 0, name: KDriveResourcesStrings.Localizable.buttonMove, icon: KDriveResourcesAsset.folderSelect)
    static let delete = MultipleSelectionAction(id: 1, name: KDriveResourcesStrings.Localizable.buttonDelete, icon: KDriveResourcesAsset.delete)
    static let more = MultipleSelectionAction(id: 2, name: KDriveResourcesStrings.Localizable.buttonMenu, icon: KDriveResourcesAsset.menu)
    static let deletePermanently = MultipleSelectionAction(id: 3, name: KDriveResourcesStrings.Localizable.buttonDelete, icon: KDriveResourcesAsset.delete)
}

@MainActor
class MultipleSelectionFileListViewModel {
    /// itemIndex
    typealias ItemSelectedCallback = (Int) -> Void
    /// selectedFiles
    typealias MoreButtonPressedCallback = ([File]) -> Void

    @Published var isMultipleSelectionEnabled: Bool {
        didSet {
            if isMultipleSelectionEnabled {
                leftBarButtons = [.cancel]
                if configuration.selectAllSupported {
                    rightBarButtons = [.selectAll]
                }
            } else {
                leftBarButtons = nil
                rightBarButtons = nil
                selectedItems.removeAll()
                selectedCount = 0
                isSelectAllModeEnabled = false
            }
        }
    }

    @Published var selectedCount: Int {
        didSet {
            updateActionButtons()
        }
    }

    @Published var leftBarButtons: [FileListBarButtonType]?
    @Published var rightBarButtons: [FileListBarButtonType]?
    @Published var multipleSelectionActions: [MultipleSelectionAction]

    var onItemSelected: ItemSelectedCallback?
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?
    var onPresentViewController: FileListViewModel.PresentViewControllerCallback?
    var onPresentQuickActionPanel: FileListViewModel.PresentQuickActionPanelCallback?

    private(set) var selectedItems = Set<File>()
    var isSelectAllModeEnabled = false

    internal var driveFileManager: DriveFileManager
    private var currentDirectory: File
    private var configuration: FileListViewModel.Configuration

    init(configuration: FileListViewModel.Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        isMultipleSelectionEnabled = false
        selectedCount = 0
        multipleSelectionActions = [.move, .delete, .more]
        self.driveFileManager = driveFileManager
        self.currentDirectory = currentDirectory
        self.configuration = configuration
    }

    func barButtonPressed(type: FileListBarButtonType) {
        switch type {
        case .selectAll:
            selectAll()
        case .deselectAll:
            deselectAll()
        case .loading:
            break
        case .cancel:
            isMultipleSelectionEnabled = false
        default:
            break
        }
    }

    func actionButtonPressed(action: MultipleSelectionAction) {
        switch action {
        case .move:
            let selectFolderNavigationController = SelectFolderViewController
                .instantiateInNavigationController(driveFileManager: driveFileManager,
                                                   startDirectory: currentDirectory,
                                                   disabledDirectoriesSelection: [selectedItems.first?.parent ?? driveFileManager.getCachedRootFile()]) { selectedFolder in
                    Task { [weak self] in
                        await self?.moveSelectedItems(to: selectedFolder)
                    }
                }
            onPresentViewController?(.modal, selectFolderNavigationController, true)
        case .delete:
            var message: NSMutableAttributedString
            if selectedCount == 1,
               let firstItem = selectedItems.first {
                message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalMoveTrashDescription(selectedItems.first!.name), boldText: firstItem.name)
            } else {
                message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalMoveTrashDescriptionPlural(selectedCount))
            }
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalMoveTrashTitle,
                                                message: message,
                                                action: KDriveResourcesStrings.Localizable.buttonMove,
                                                destructive: true, loading: true) { [weak self] in
                await self?.deleteSelectedItems()
            }
            onPresentViewController?(.modal, alert, true)
        case .more:
            onPresentQuickActionPanel?(Array(selectedItems), .multipleSelection)
        default:
            break
        }
    }

    private func updateActionButtons() {
        let notEmpty = selectedCount > 0
        let canMove = selectedItems.allSatisfy { $0.capabilities.canMove }
        let canDelete = selectedItems.allSatisfy { $0.capabilities.canDelete }

        for i in 0 ..< multipleSelectionActions.count {
            var updatedAction: MultipleSelectionAction
            switch multipleSelectionActions[i] {
            case .move:
                updatedAction = MultipleSelectionAction.move
                updatedAction.enabled = notEmpty && canMove
            case .delete:
                updatedAction = MultipleSelectionAction.delete
                updatedAction.enabled = notEmpty && canDelete
            case .more:
                updatedAction = MultipleSelectionAction.more
                updatedAction.enabled = notEmpty
            case .deletePermanently:
                updatedAction = MultipleSelectionAction.deletePermanently
                updatedAction.enabled = notEmpty
            default:
                updatedAction = multipleSelectionActions[i]
            }
            multipleSelectionActions[i] = updatedAction
        }
    }

    func selectAll() {
        selectedItems.removeAll()
        isSelectAllModeEnabled = true
        rightBarButtons = [.loading]
        onSelectAll?()
        let frozenDirectory = currentDirectory.freeze()
        Task {
            do {
                let directoryCount = try await driveFileManager.apiFetcher.count(of: frozenDirectory)
                selectedCount = directoryCount.count
                rightBarButtons = [.deselectAll]
            } catch {
                deselectAll()
            }
        }
    }

    func deselectAll() {
        selectedCount = 0
        selectedItems.removeAll()
        isSelectAllModeEnabled = false
        rightBarButtons = [.selectAll]
        onDeselectAll?()
    }

    func didSelectFile(_ file: File, at index: Int) {
        selectedItems.insert(file)
        selectedCount = selectedItems.count
        onItemSelected?(index)
    }

    func didDeselectFile(_ file: File, at index: Int) {
        if isSelectAllModeEnabled {
            deselectAll()
            didSelectFile(file, at: index)
        } else {
            selectedItems.remove(file)
            selectedCount = selectedItems.count
        }
    }

    func moveSelectedItems(to destinationDirectory: File) async {
        if isSelectAllModeEnabled {
            await bulkMoveAll(destinationId: destinationDirectory.id)
        } else if selectedCount > Constants.bulkActionThreshold {
            await bulkMoveFiles(Array(selectedItems), destinationId: destinationDirectory.id)
        } else {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for file in selectedItems {
                        group.addTask { [self] in
                            _ = try await driveFileManager.move(file: file, to: destinationDirectory)
                        }
                    }
                    try await group.waitForAll()
                }
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListMoveFileConfirmationSnackbar(selectedItems.count, destinationDirectory.name))
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            isMultipleSelectionEnabled = false
        }
    }

    func deleteSelectedItems() async {
        // TODO: check this working
        if isSelectAllModeEnabled {
            await bulkDeleteAll()
        } else if selectedCount > Constants.bulkActionThreshold {
            await bulkDeleteFiles(Array(selectedItems))
        } else {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for file in selectedItems {
                        group.addTask { [self] in
                            _ = try await driveFileManager.delete(file: file)
                        }
                    }
                    try await group.waitForAll()
                }

                let message: String
                if selectedCount == 1,
                   let firstItem = selectedItems.first {
                    message = KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(firstItem.name)
                } else {
                    message = KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmationPlural(selectedCount)
                }

                UIConstants.showSnackBar(message: message)
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }

            isMultipleSelectionEnabled = false
        }
    }

    // MARK: - Bulk actions

    private func bulkMoveFiles(_ files: [File], destinationId: Int) async {
        let action = BulkAction(action: .move, fileIds: files.map(\.id), destinationDirectoryId: destinationId)
        await performAndObserve(bulkAction: action)
    }

    private func bulkMoveAll(destinationId: Int) async {
        let action = BulkAction(action: .move, parentId: currentDirectory.id, destinationDirectoryId: destinationId)
        await performAndObserve(bulkAction: action)
    }

    private func bulkDeleteFiles(_ files: [File]) async {
        let action = BulkAction(action: .trash, fileIds: files.map(\.id))
        await performAndObserve(bulkAction: action)
    }

    private func bulkDeleteAll() async {
        let action = BulkAction(action: .trash, parentId: currentDirectory.id)
        await performAndObserve(bulkAction: action)
    }

    public func performAndObserve(bulkAction: BulkAction) async {
        do {
            isMultipleSelectionEnabled = false
            let cancelableResponse = try await driveFileManager.apiFetcher.bulkAction(drive: driveFileManager.drive, action: bulkAction)

            let message: String
            let cancelMessage: String
            switch bulkAction.action {
            case .trash:
                message = KDriveResourcesStrings.Localizable.fileListDeletionStartedSnackbar
                cancelMessage = KDriveResourcesStrings.Localizable.allTrashActionCancelled
            case .move:
                message = KDriveResourcesStrings.Localizable.fileListMoveStartedSnackbar
                cancelMessage = KDriveResourcesStrings.Localizable.allFileDuplicateCancelled
            case .copy:
                message = KDriveResourcesStrings.Localizable.fileListCopyStartedSnackbar
                cancelMessage = KDriveResourcesStrings.Localizable.allFileDuplicateCancelled
            }
            let progressSnack = UIConstants.showCancelableSnackBar(message: message,
                                                                   cancelSuccessMessage: cancelMessage,
                                                                   duration: .infinite,
                                                                   cancelableResponse: cancelableResponse,
                                                                   driveFileManager: driveFileManager)

            AccountManager.instance.mqService.observeActionProgress(self, actionId: cancelableResponse.id) { actionProgress in
                DispatchQueue.main.async { [weak self] in
                    switch actionProgress.progress.message {
                    case .starting:
                        break
                    case .processing:
                        switch bulkAction.action {
                        case .trash:
                            progressSnack?.message = KDriveResourcesStrings.Localizable.fileListDeletionInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                        case .move:
                            progressSnack?.message = KDriveResourcesStrings.Localizable.fileListMoveInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                        case .copy:
                            progressSnack?.message = KDriveResourcesStrings.Localizable.fileListCopyInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                        }
                        self?.notifyObserversForCurrentDirectory()
                    case .done:
                        switch bulkAction.action {
                        case .trash:
                            progressSnack?.message = KDriveResourcesStrings.Localizable.fileListDeletionDoneSnackbar
                        case .move:
                            progressSnack?.message = KDriveResourcesStrings.Localizable.fileListMoveDoneSnackbar
                        case .copy:
                            progressSnack?.message = KDriveResourcesStrings.Localizable.fileListCopyDoneSnackbar
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            progressSnack?.dismiss()
                        }
                        self?.notifyObserversForCurrentDirectory()
                    case .canceled:
                        let message: String
                        switch bulkAction.action {
                        case .trash:
                            message = KDriveResourcesStrings.Localizable.allTrashActionCancelled
                        case .move:
                            message = KDriveResourcesStrings.Localizable.allFileMoveCancelled
                        case .copy:
                            message = KDriveResourcesStrings.Localizable.allFileDuplicateCancelled
                        }
                        UIConstants.showSnackBar(message: message)
                        self?.notifyObserversForCurrentDirectory()
                    }
                }
            }
        } catch {
            DDLogError("Error while performing bulk action: \(error)")
        }
    }

    private func notifyObserversForCurrentDirectory() {
        driveFileManager.notifyObserversWith(file: currentDirectory)
    }
}
