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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

@MainActor
class DraggableFileListViewModel {
    var driveFileManager: DriveFileManager

    init(driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager
    }

    func dragItems(
        for draggedFile: File,
        in collectionView: UICollectionView,
        at indexPath: IndexPath,
        with session: UIDragSession
    ) -> [UIDragItem] {
        guard draggedFile.capabilities.canMove && !driveFileManager.drive.sharedWithMe && !draggedFile.isTrashed else {
            return []
        }

        let dragAndDropFile = DragAndDropFile(file: draggedFile, userId: driveFileManager.drive.userId)
        let itemProvider = NSItemProvider(object: dragAndDropFile)
        itemProvider.suggestedName = draggedFile.name
        let draggedItem = UIDragItem(itemProvider: itemProvider)
        if let previewImageView = (collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell)?.logoImage {
            draggedItem.previewProvider = {
                UIDragPreview(view: previewImageView)
            }
        }
        session.localContext = draggedFile

        return [draggedItem]
    }
}

@MainActor
final class DroppableFileListViewModel {
    @LazyInjectService var fileImportHelper: FileImportHelper

    var driveFileManager: DriveFileManager
    private var currentDirectory: File
    private var lastDropPosition: DropPosition?
    var onFilePresented: FileListViewModel.FilePresentedCallback?

    init(driveFileManager: DriveFileManager, currentDirectory: File) {
        self.driveFileManager = driveFileManager
        self.currentDirectory = currentDirectory
    }

    private func handleDropOverDirectory(_ directory: File,
                                         in collectionView: UICollectionView,
                                         at indexPath: IndexPath) -> UICollectionViewDropProposal {
        guard directory.capabilities.canUpload && directory.capabilities.canMoveInto else {
            return UICollectionViewDropProposal(operation: .forbidden, intent: .insertIntoDestinationIndexPath)
        }

        if let currentLastDropPosition = lastDropPosition {
            if currentLastDropPosition.indexPath == indexPath {
                collectionView.cellForItem(at: indexPath)?.isHighlighted = true
                if UIConstants.dropDelay > currentLastDropPosition.time.timeIntervalSinceNow {
                    lastDropPosition = nil
                    collectionView.cellForItem(at: indexPath)?.isHighlighted = false
                    onFilePresented?(directory)
                }
            } else {
                collectionView.cellForItem(at: currentLastDropPosition.indexPath)?.isHighlighted = false
                lastDropPosition = DropPosition(indexPath: indexPath)
            }
        } else {
            lastDropPosition = DropPosition(indexPath: indexPath)
        }
        return UICollectionViewDropProposal(operation: .copy, intent: .insertIntoDestinationIndexPath)
    }

    func handleLocalDrop(localItemProviders: [NSItemProvider], destinationDirectory: File) {
        let frozenDestinationDirectory = destinationDirectory.freezeIfNeeded()
        for localFile in localItemProviders {
            localFile
                .loadObject(ofClass: DragAndDropFile.self) { [destinationDriveFileManager = driveFileManager] itemProvider, _ in
                    Task { @MainActor in
                        guard let itemProvider = itemProvider as? DragAndDropFile,
                              let file = itemProvider.file else {
                            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)

                            return
                        }

                        FileActionsHelper.instance.move(
                            file: file,
                            to: frozenDestinationDirectory,
                            sourceDriveFileManager: destinationDriveFileManager,
                            destinationDriveFileManager: destinationDriveFileManager
                        )
                    }
                }
        }
    }

    func handleExternalDrop(externalFiles: [NSItemProvider], destinationDirectory: File) {
        if !externalFiles.isEmpty {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarProcessingUploads)
            _ = fileImportHelper.importItems(externalFiles) { [
                weak self,
                frozenDestination = destinationDirectory.freeze()
            ] importedFiles, errorCount in
                guard let self else { return }
                if errorCount > 0 {
                    Task {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarUploadError(errorCount))
                    }
                }
                guard !importedFiles.isEmpty else {
                    return
                }

                let drive = driveFileManager.drive
                Task {
                    do {
                        try await self.fileImportHelper.saveForUpload(
                            importedFiles,
                            in: frozenDestination,
                            drive: drive,
                            addToQueue: true
                        )
                    } catch {
                        UIConstants.showSnackBarIfNeeded(error: error)
                    }
                }
            }
        }
    }

    func updateDropSession(_ session: UIDropSession,
                           in collectionView: UICollectionView,
                           with destinationIndexPath: IndexPath?,
                           destinationFile: File?) -> UICollectionViewDropProposal {
        if let indexPath = destinationIndexPath,
           let destinationFile,
           destinationFile.isDirectory {
            if let draggedFile = session.localDragSession?.localContext as? File,
               draggedFile.id == destinationFile.id {
                if let indexPath = lastDropPosition?.indexPath {
                    collectionView.cellForItem(at: indexPath)?.isHighlighted = false
                }
                return UICollectionViewDropProposal(operation: .forbidden, intent: .insertIntoDestinationIndexPath)
            } else {
                return handleDropOverDirectory(destinationFile, in: collectionView, at: indexPath)
            }
        } else {
            if let indexPath = lastDropPosition?.indexPath {
                collectionView.cellForItem(at: indexPath)?.isHighlighted = false
            }
            return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
        }
    }

    func performDrop(with coordinator: UICollectionViewDropCoordinator,
                     in collectionView: UICollectionView,
                     destinationDirectory: File) {
        let itemProviders = coordinator.items.map(\.dragItem.itemProvider)
        // We don't display iOS's progress indicator because we use our own snackbar
        coordinator.session.progressIndicatorStyle = .none

        if let lastHighlightedPath = lastDropPosition?.indexPath {
            collectionView.cellForItem(at: lastHighlightedPath)?.isHighlighted = false
        }

        let localFiles = itemProviders.filter { $0.canLoadObject(ofClass: DragAndDropFile.self) }
        handleLocalDrop(localItemProviders: localFiles, destinationDirectory: destinationDirectory)

        let externalFiles = itemProviders.filter { !$0.canLoadObject(ofClass: DragAndDropFile.self) }
        handleExternalDrop(externalFiles: externalFiles, destinationDirectory: destinationDirectory)
    }
}
