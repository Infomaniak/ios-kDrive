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
        let canMove = selectedItems.allSatisfy { $0.capabilities.canMove }
        let isInTrash: Bool
        #if ISEXTENSION
        isInTrash = false
        #else
        isInTrash = self is TrashViewController
        #endif
        let canDelete = isInTrash || selectedItems.allSatisfy { $0.capabilities.canDelete }
        setSelectionButtonsEnabled(moveEnabled: notEmpty && canMove, deleteEnabled: notEmpty && canDelete, moreEnabled: notEmpty)
    }

    func setSelectionButtonsEnabled(moveEnabled: Bool, deleteEnabled: Bool, moreEnabled: Bool) {}

    func updateSelectedCount() {}

    func getNewChanges() {}

    func multipleSelectionActionButtonPressed(_ button: SelectView.MultipleSelectionActionButton) {}
}
