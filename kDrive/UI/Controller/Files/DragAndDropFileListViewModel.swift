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
import kDriveResources
import UIKit

protocol DraggableFileListViewModel: AnyObject where Self: FileListViewModel {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
}

extension DraggableFileListViewModel {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard indexPath.item < fileCount else { return [] }

        let draggedFile = getFile(at: indexPath.item)
        guard draggedFile.rights?.move == true && !driveFileManager.drive.sharedWithMe && !draggedFile.isTrashed else {
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

protocol DroppableFileListViewModel: AnyObject where Self: FileListViewModel {
    var lastDropPosition: DropPosition? { get set }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator)
}

extension DroppableFileListViewModel {
    private func handleDropOverDirectory(_ directory: File, in collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionViewDropProposal {
        guard directory.rights?.uploadNewFile == true && directory.rights?.moveInto == true else {
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
        for localFile in localItemProviders {
            localFile.loadObject(ofClass: DragAndDropFile.self) { [weak self] itemProvider, _ in
                guard let self = self else { return }
                if let itemProvider = itemProvider as? DragAndDropFile,
                   let file = itemProvider.file {
                    let destinationDriveFileManager = self.driveFileManager
                    if itemProvider.driveId == destinationDriveFileManager.drive.id && itemProvider.userId == destinationDriveFileManager.drive.userId {
                        if destinationDirectory.id == file.parentId { return }
                        destinationDriveFileManager.moveFile(file: file, newParent: destinationDirectory) { response, _, error in
                            if error != nil {
                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorMove)
                            } else {
                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListMoveFileConfirmationSnackbar(1, destinationDirectory.name), action: .init(title: KDriveResourcesStrings.Localizable.buttonCancel) {
                                    if let cancelId = response?.id {
                                        self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                            if error == nil {
                                                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.allFileMoveCancelled)
                                            }
                                        }
                                    }
                                })
                            }
                        }
                    } else {
                        // TODO: enable copy from different driveFileManager
                        DispatchQueue.main.async {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorMove)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        UIConstants.showSnackBar(message: DriveError.unknownError.localizedDescription)
                    }
                }
            }
        }
    }

    func handleExternalDrop(externalFiles: [NSItemProvider], destinationDirectory: File) {
        if !externalFiles.isEmpty {
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarProcessingUploads)
            _ = FileImportHelper.instance.importItems(externalFiles) { [weak self] importedFiles, errorCount in
                guard let self = self else { return }
                if errorCount > 0 {
                    DispatchQueue.main.async {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackBarUploadError(errorCount))
                    }
                }
                guard !importedFiles.isEmpty else {
                    return
                }
                do {
                    try FileImportHelper.instance.upload(files: importedFiles, in: destinationDirectory, drive: self.driveFileManager.drive)
                } catch {
                    DispatchQueue.main.async {
                        UIConstants.showSnackBar(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let indexPath = destinationIndexPath,
           indexPath.item < fileCount && getFile(at: indexPath.item).isDirectory {
            if let draggedFile = session.localDragSession?.localContext as? File,
               draggedFile.id == getFile(at: indexPath.item).id {
                if let indexPath = lastDropPosition?.indexPath {
                    collectionView.cellForItem(at: indexPath)?.isHighlighted = false
                }
                return UICollectionViewDropProposal(operation: .forbidden, intent: .insertIntoDestinationIndexPath)
            } else {
                return handleDropOverDirectory(getFile(at: indexPath.item), in: collectionView, at: indexPath)
            }
        } else {
            if let indexPath = lastDropPosition?.indexPath {
                collectionView.cellForItem(at: indexPath)?.isHighlighted = false
            }
            return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let itemProviders = coordinator.items.map(\.dragItem.itemProvider)
        // We don't display iOS's progress indicator because we use our own snackbar
        coordinator.session.progressIndicatorStyle = .none

        let destinationDirectory: File
        if let indexPath = coordinator.destinationIndexPath,
           indexPath.item < fileCount && getFile(at: indexPath.item).isDirectory &&
           getFile(at: indexPath.item).rights?.uploadNewFile == true {
            destinationDirectory = getFile(at: indexPath.item)
        } else {
            destinationDirectory = currentDirectory
        }

        if let lastHighlightedPath = lastDropPosition?.indexPath {
            collectionView.cellForItem(at: lastHighlightedPath)?.isHighlighted = false
        }

        let localFiles = itemProviders.filter { $0.canLoadObject(ofClass: DragAndDropFile.self) }
        handleLocalDrop(localItemProviders: localFiles, destinationDirectory: destinationDirectory)

        let externalFiles = itemProviders.filter { !$0.canLoadObject(ofClass: DragAndDropFile.self) }
        handleExternalDrop(externalFiles: externalFiles, destinationDirectory: destinationDirectory)
    }
}
