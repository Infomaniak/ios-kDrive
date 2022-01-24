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

class MultipleSelectionViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!

    var driveFileManager: DriveFileManager!
    var selectedItems = Set<File>()
    var rightBarButtonItems: [UIBarButtonItem]?
    var leftBarButtonItems: [UIBarButtonItem]?

    var selectionMode = false {
        didSet {
            toggleMultipleSelection()
        }
    }

    func getItem(at indexPath: IndexPath) -> File? {
        return nil
    }

    func getAllItems() -> [File] {
        return []
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        selectionMode = false
    }

    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard !selectionMode else { return }
        let pos = sender.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: pos) {
            selectionMode = true
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .init(rawValue: 0))
            selectChild(at: indexPath)
        }
    }

    func toggleMultipleSelection() {}

    @objc func cancelMultipleSelection() {
        selectionMode = false
    }

    func selectAllChildren() {
        selectedItems = Set(getAllItems())
        for index in 0 ..< selectedItems.count {
            let indexPath = IndexPath(row: index, section: 0)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
        }
        updateSelectionButtons()
        updateSelectedCount()
    }

    func selectChild(at indexPath: IndexPath) {
        if let item = getItem(at: indexPath) {
            selectedItems.insert(item)
            updateSelectionButtons()
        }
        updateSelectedCount()
    }

    func deselectAllChildren() {
        if let indexPaths = collectionView.indexPathsForSelectedItems {
            for indexPath in indexPaths {
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }
        selectedItems.removeAll()
        updateSelectionButtons()
    }

    func deselectChild(at indexPath: IndexPath) {
        if let selectedItem = getItem(at: indexPath),
           let index = selectedItems.firstIndex(of: selectedItem) {
            selectedItems.remove(at: index)
        }
        updateSelectionButtons()
        updateSelectedCount()
    }

    /// Select collection view cells based on `selectedItems`
    func setSelectedCells() {}

    /// Update selected items with new objects
    func updateSelectedItems(newChildren: [File]) {
        let selectedFileId = selectedItems.map(\.id)
        selectedItems = Set(newChildren.filter { selectedFileId.contains($0.id) })
    }

    final func updateSelectionButtons(selectAll: Bool = false) {
        let notEmpty = !selectedItems.isEmpty || selectAll
        let canMove = selectedItems.allSatisfy { $0.rights?.move ?? false }
        let isInTrash: Bool
        #if ISEXTENSION
        isInTrash = false
        #else
        isInTrash = self is TrashViewController
        #endif
        let canDelete = isInTrash || selectedItems.allSatisfy { $0.rights?.delete ?? false }
        setSelectionButtonsEnabled(moveEnabled: notEmpty && canMove, deleteEnabled: notEmpty && canDelete, moreEnabled: notEmpty)
    }

    func setSelectionButtonsEnabled(moveEnabled: Bool, deleteEnabled: Bool, moreEnabled: Bool) {}

    func updateSelectedCount() {}

    func getNewChanges() {}

    // MARK: - Actions

    #if !ISEXTENSION
    func moveSelectedItems() {
        let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, disabledDirectoriesSelection: [selectedItems.first?.parent ?? driveFileManager.getRootFile()]) { [unowned self] selectedFolder in
            Task {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        for file in self.selectedItems {
                            group.addTask {
                                _ = try await driveFileManager.move(file: file, to: selectedFolder)
                            }
                        }
                        try await group.waitForAll()
                    }
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListMoveFileConfirmationSnackbar(self.selectedItems.count, selectedFolder.name))
                } catch {
                    UIConstants.showSnackBar(message: error.localizedDescription)
                }
                self.selectionMode = false
                self.getNewChanges()
            }
        }
        present(selectFolderNavigationController, animated: true)
    }

    func deleteSelectedItems() {
        let message: NSMutableAttributedString
        if selectedItems.count == 1 {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalMoveTrashDescription(selectedItems.first!.name), boldText: selectedItems.first!.name)
        } else {
            message = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalMoveTrashDescriptionPlural(selectedItems.count))
        }

        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalMoveTrashTitle, message: message, action: KDriveResourcesStrings.Localizable.buttonMove, destructive: true, loading: true) {
            do {
                try await self.delete(files: Array(self.selectedItems))
                let message: String
                if self.selectedItems.count == 1 {
                    message = KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(self.selectedItems.first!.name)
                } else {
                    message = KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmationPlural(self.selectedItems.count)
                }
                UIConstants.showSnackBar(message: message)
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            self.selectionMode = false
            self.getNewChanges()
        }
        present(alert, animated: true)
    }

    @discardableResult
    func delete(files: [File]) async throws -> [CancelableResponse] {
        return try await withThrowingTaskGroup(of: CancelableResponse.self, returning: [CancelableResponse].self) { group in
            for file in files {
                group.addTask {
                    try await self.driveFileManager.delete(file: file)
                }
            }

            var responses = [CancelableResponse]()
            for try await response in group {
                responses.append(response)
            }
            return responses
        }
    }

    func delete(file: File) {
        Task {
            do {
                let responses = try await delete(files: [file])
                UIConstants.showCancelableSnackBar(message: KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(file.name), cancelSuccessMessage: KDriveResourcesStrings.Localizable.allTrashActionCancelled, cancelableResponse: responses.first!, driveFileManager: driveFileManager)
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
        }
    }

    func showMenuForSelection() {
        let floatingPanelViewController = DriveFloatingPanelController()
        let selectViewController = SelectFloatingPanelTableViewController()
        selectViewController.presentingParent = self
        floatingPanelViewController.isRemovalInteractionEnabled = true
        selectViewController.files = Array(selectedItems)
        floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 325)
        selectViewController.driveFileManager = driveFileManager
        selectViewController.reloadAction = { [unowned self] in
            selectionMode = false
            getNewChanges()
        }
        floatingPanelViewController.set(contentViewController: selectViewController)
        floatingPanelViewController.track(scrollView: selectViewController.collectionView)
        present(floatingPanelViewController, animated: true)
    }
    #endif
}
