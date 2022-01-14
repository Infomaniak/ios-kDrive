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

import Foundation
import kDriveCore

enum MultipleSelectionBarButtonType {
    case selectAll
    case deselectAll
    case loading
    case cancel
}

class MultipleSelectionFileListViewModel {
    /// itemIndex
    typealias ItemSelectedCallback = (Int) -> Void

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
                selectedIndexes.removeAll()
                selectedCount = 0
                isSelectAllModeEnabled = false
            }
        }
    }

    @Published var selectedCount: Int
    @Published var leftBarButtons: [MultipleSelectionBarButtonType]?
    @Published var rightBarButtons: [MultipleSelectionBarButtonType]?

    var onItemSelected: ItemSelectedCallback?
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?

    private(set) var selectedIndexes = Set<Int>()
    var isSelectAllModeEnabled = false

    private var driveFileManager: DriveFileManager
    private var currentDirectory: File
    private var configuration: FileListViewController.Configuration

    init(configuration: FileListViewController.Configuration, driveFileManager: DriveFileManager, currentDirectory: File) {
        isMultipleSelectionEnabled = false
        selectedCount = 0
        self.driveFileManager = driveFileManager
        self.currentDirectory = currentDirectory
        self.configuration = configuration
    }

    func barButtonPressed(type: MultipleSelectionBarButtonType) {
        switch type {
        case .selectAll:
            selectAll()
        case .deselectAll:
            deselectAll()
        case .loading:
            break
        case .cancel:
            isMultipleSelectionEnabled = false
        }
    }

    func selectAll() {
        selectedIndexes.removeAll()
        isSelectAllModeEnabled = true
        onSelectAll?()
        rightBarButtons = [.loading]
        let frozenDirectory = currentDirectory.freeze()
        Task {
            let directoryCount = try await driveFileManager.apiFetcher.count(of: frozenDirectory)
            selectedCount = directoryCount.count
            rightBarButtons = [.deselectAll]
        }
    }

    func deselectAll() {
        selectedCount = 0
        selectedIndexes.removeAll()
        isSelectAllModeEnabled = false
        rightBarButtons = [.selectAll]
        onDeselectAll?()
    }

    func didSelectItem(at index: Int) {
        selectedIndexes.insert(index)
        selectedCount = selectedIndexes.count
        onItemSelected?(index)
    }

    func didDeselectItem(at index: Int) {
        if isSelectAllModeEnabled {
            deselectAll()
            didSelectItem(at: index)
        } else {
            selectedIndexes.remove(index)
            selectedCount = selectedIndexes.count
        }
    }
}
