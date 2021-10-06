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
import UIKit

class MultipleSelectionViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!

    var driveFileManager: DriveFileManager!
    var selectedItems = Set<File>()
    var rightBarButtonItems: [UIBarButtonItem]?

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
            let group = DispatchGroup()
            var success = true
            for file in self.selectedItems {
                group.enter()
                driveFileManager.moveFile(file: file, newParent: selectedFolder) { _, _, error in
                    if let error = error {
                        success = false
                        DDLogError("Error while moving file: \(error)")
                    }
                    group.leave()
                }
            }
            group.notify(queue: DispatchQueue.main) {
                let message = success ? KDriveStrings.Localizable.fileListMoveFileConfirmationSnackbar(self.selectedItems.count, selectedFolder.name) : KDriveStrings.Localizable.errorMove
                UIConstants.showSnackBar(message: message)
                self.selectionMode = false
                self.getNewChanges()
            }
        }
        present(selectFolderNavigationController, animated: true)
    }

    func deleteSelectedItems() {
        let message: NSMutableAttributedString
        if selectedItems.count == 1 {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescription(selectedItems.first!.name), boldText: selectedItems.first!.name)
        } else {
            message = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescriptionPlural(selectedItems.count))
        }

        let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalMoveTrashTitle, message: message, action: KDriveStrings.Localizable.buttonMove, destructive: true, loading: true) {
            let message: String
            if let success = self.deleteFiles(Array(self.selectedItems), async: false), success {
                if self.selectedItems.count == 1 {
                    message = KDriveStrings.Localizable.snackbarMoveTrashConfirmation(self.selectedItems.first!.name)
                } else {
                    message = KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(self.selectedItems.count)
                }
            } else {
                message = KDriveStrings.Localizable.errorMove
            }
            DispatchQueue.main.async {
                UIConstants.showSnackBar(message: message)
                self.selectionMode = false
                self.getNewChanges()
            }
        }
        present(alert, animated: true)
    }

    @discardableResult
    func deleteFiles(_ files: [File], async: Bool = true) -> Bool? {
        let group = DispatchGroup()
        var success = true
        var cancelId: String?
        for file in files {
            group.enter()
            driveFileManager.deleteFile(file: file) { response, error in
                cancelId = response?.id
                if let error = error {
                    success = false
                    DDLogError("Error while deleting file: \(error)")
                }
                group.leave()
            }
        }
        if async {
            group.notify(queue: DispatchQueue.main) {
                if success {
                    if files.count == 1 {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmation(files[0].name), action: .init(title: KDriveStrings.Localizable.buttonCancel) {
                            guard let cancelId = cancelId else { return }
                            self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                self.getNewChanges()
                                if error == nil {
                                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.allTrashActionCancelled)
                                }
                            }
                        })
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmationPlural(files.count))
                    }
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorMove)
                }
                if self.selectionMode {
                    self.selectionMode = false
                }
                self.getNewChanges()
            }
            return nil
        } else {
            let result = group.wait(timeout: .now() + Constants.timeout)
            return success && result != .timedOut
        }
    }

    func showMenuForSelection() {
        let floatingPanelViewController = DriveFloatingPanelController()
        let selectViewController = SelectFloatingPanelTableViewController()
        floatingPanelViewController.isRemovalInteractionEnabled = true
        selectViewController.files = Array(selectedItems)
        floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 260)
        selectViewController.driveFileManager = driveFileManager
        selectViewController.reloadAction = { [unowned self] in
            selectionMode = false
            getNewChanges()
        }
        floatingPanelViewController.set(contentViewController: selectViewController)
        floatingPanelViewController.track(scrollView: selectViewController.tableView)
        present(floatingPanelViewController, animated: true)
    }
    #endif
}
