/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2025 Infomaniak Network SA

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

import UIKit
import InfomaniakCore

// MARK: - UICollectionViewDragDelegate

extension ModernFileListViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        if let draggableViewModel = viewModel.draggableFileListViewModel,
           let draggedFile = getDisplayedFile(at: indexPath) {
            return draggableViewModel.dragItems(for: draggedFile, in: collectionView, at: indexPath, with: session)
        } else {
            return []
        }
    }
}

// MARK: - UICollectionViewDropDelegate

extension ModernFileListViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        // Prevent dropping a session with only folders
        return !session.items.allSatisfy { $0.itemProvider.hasItemConformingToTypeIdentifier(UTI.directory.identifier) }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        if let droppableViewModel = viewModel.droppableFileListViewModel,
           let destinationIndexPath {
            let file = getDisplayedFile(at: destinationIndexPath)
            return droppableViewModel.updateDropSession(
                session,
                in: collectionView,
                with: destinationIndexPath,
                destinationFile: file
            )
        } else {
            return UICollectionViewDropProposal(operation: .cancel, intent: .unspecified)
        }
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        if let droppableViewModel = viewModel.droppableFileListViewModel {
            var destinationDirectory = viewModel.currentDirectory

            if let indexPath = coordinator.destinationIndexPath,
               indexPath.item < viewModel.files.count,
               let file = getDisplayedFile(at: indexPath),
               file.isDirectory && file.capabilities.canUpload {
                destinationDirectory = file
            }

            droppableViewModel.performDrop(with: coordinator, in: collectionView, destinationDirectory: destinationDirectory)
        }
    }
}
