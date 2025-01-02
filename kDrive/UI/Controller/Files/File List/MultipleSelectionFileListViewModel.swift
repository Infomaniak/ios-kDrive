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
import InfomaniakCore
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

    static let move = MultipleSelectionAction(
        id: 0,
        name: KDriveResourcesStrings.Localizable.buttonMove,
        icon: KDriveResourcesAsset.folderSelect
    )
    static let delete = MultipleSelectionAction(
        id: 1,
        name: KDriveResourcesStrings.Localizable.buttonDelete,
        icon: KDriveResourcesAsset.delete
    )
    static let more = MultipleSelectionAction(
        id: 2,
        name: KDriveResourcesStrings.Localizable.buttonMenu,
        icon: KDriveResourcesAsset.menu
    )
    static let deletePermanently = MultipleSelectionAction(
        id: 3,
        name: KDriveResourcesStrings.Localizable.buttonDelete,
        icon: KDriveResourcesAsset.delete
    )
}

@MainActor
class MultipleSelectionFileListViewModel {
    /// itemIndex
    typealias ItemSelectedCallback = (IndexPath) -> Void
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
                exceptItemIds.removeAll()
                selectedCount = 0
                isSelectAllModeEnabled = false
                onDeselectAll?()
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
    private(set) var exceptItemIds = Set<Int>()
    var isSelectAllModeEnabled = false

    var driveFileManager: DriveFileManager
    private var currentDirectory: File
    private var configuration: FileListViewModel.Configuration

    init(configuration: FileListViewModel.Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        isMultipleSelectionEnabled = false
        selectedCount = 0

        self.driveFileManager = driveFileManager

        if driveFileManager.isPublicShare {
            multipleSelectionActions = []
        } else {
            multipleSelectionActions = [.move, .delete, .more]
        }

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
            FileActionsHelper.move(files: Array(selectedItems),
                                   exceptFileIds: Array(exceptItemIds),
                                   from: currentDirectory,
                                   allItemsSelected: isSelectAllModeEnabled,
                                   observer: self,
                                   driveFileManager: driveFileManager) { [weak self] viewController in
                self?.onPresentViewController?(.modal, viewController, true)
            } completion: { [weak self] in
                self?.isMultipleSelectionEnabled = false
            }
        case .delete:
            var message: NSMutableAttributedString
            if selectedCount == 1,
               let firstItem = selectedItems.first {
                message = NSMutableAttributedString(
                    string: KDriveResourcesStrings.Localizable.modalMoveTrashDescription(selectedItems.first!.name),
                    boldText: firstItem.name
                )
            } else {
                message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable
                    .modalMoveTrashDescriptionPlural(selectedCount))
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
        let canMove = selectedItems.allSatisfy(\.capabilities.canMove)
        let canDelete = selectedItems.allSatisfy(\.capabilities.canDelete)

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
        Task { [proxyCurrentDirectory = currentDirectory.proxify()] in
            do {
                let directoryCount = try await driveFileManager.apiFetcher.count(of: proxyCurrentDirectory)
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
        exceptItemIds.removeAll()
        isSelectAllModeEnabled = false
        rightBarButtons = [.selectAll]
        onDeselectAll?()
    }

    func didSelectFile(_ file: File, at indexPath: IndexPath) {
        if isSelectAllModeEnabled {
            selectedCount += 1
            exceptItemIds.remove(file.id)
        } else {
            selectedItems.insert(file)
            selectedCount = selectedItems.count
        }
        onItemSelected?(indexPath)
    }

    func didDeselectFile(_ file: File, at indexPath: IndexPath) {
        if isSelectAllModeEnabled {
            selectedCount -= 1
            exceptItemIds.insert(file.id)
            if selectedCount == 0 {
                deselectAll()
            }
        } else {
            selectedItems.remove(file)
            selectedCount = selectedItems.count
        }
    }

    func deleteSelectedItems() async {
        if isSelectAllModeEnabled {
            await bulkDeleteAll()
        } else if selectedCount > Constants.bulkActionThreshold {
            await bulkDeleteFiles(Array(selectedItems))
        } else {
            do {
                let proxySelectedItems = selectedItems.map { $0.proxify() }
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for proxyFile in proxySelectedItems {
                        group.addTask { [self] in
                            _ = try await driveFileManager.delete(file: proxyFile)
                        }
                    }
                    try await group.waitForAll()
                }

                UIConstants
                    .showSnackBar(message: KDriveResourcesStrings.Localizable
                        .fileListMoveTrashConfirmationSnackbar(proxySelectedItems.count))
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }

            isMultipleSelectionEnabled = false
        }
    }

    // MARK: - Bulk actions

    private func bulkDeleteFiles(_ files: [File]) async {
        let action = BulkAction(action: .trash, fileIds: files.map(\.id))
        await performAndObserve(bulkAction: action)
    }

    private func bulkDeleteAll() async {
        let action = BulkAction(action: .trash, parentId: currentDirectory.id, exceptFileIds: Array(exceptItemIds))
        await performAndObserve(bulkAction: action)
    }

    public func performAndObserve(bulkAction: BulkAction) async {
        await FileActionsHelper.performAndObserve(bulkAction: bulkAction,
                                                  from: currentDirectory,
                                                  observer: self,
                                                  driveFileManager: driveFileManager) { [weak self] in
            self?.isMultipleSelectionEnabled = false
        }
    }
}
