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
import kDriveResources
import UIKit
import kDriveCore

@MainActor
public class FileActionsHelper {
    public static let instance = FileActionsHelper()

    private var interactionController: UIDocumentInteractionController!

    // MARK: - Single file

    public func openWith(file: File, from rect: CGRect, in view: UIView, delegate: UIDocumentInteractionControllerDelegate) {
        guard let rootFolderURL = DriveFileManager.constants.openInPlaceDirectoryURL else {
            DDLogError("Open in place directory not found")
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
            return
        }

        do {
            // Create directory if needed
            let folderURL = rootFolderURL.appendingPathComponent("\(file.driveId)", isDirectory: true)
                .appendingPathComponent("\(file.id)", isDirectory: true)
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            // Copy file
            let fileUrl = folderURL.appendingPathComponent(file.name)
            var shouldCopy = true
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
                let modificationDate = attributes[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
                if file.lastModifiedAt > modificationDate {
                    try FileManager.default.removeItem(at: fileUrl)
                } else {
                    shouldCopy = false
                }
            }
            if shouldCopy {
                try FileManager.default.copyItem(at: file.localUrl, to: fileUrl)
            }

            interactionController = UIDocumentInteractionController(url: fileUrl)
            interactionController.delegate = delegate
            interactionController.presentOpenInMenu(from: rect, in: view, animated: true)
        } catch {
            DDLogError("Cannot present interaction controller: \(error)")
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
        }
    }

    public func move(file: File, to destinationDirectory: File, driveFileManager: DriveFileManager, completion: ((Bool) -> Void)? = nil) {
        guard destinationDirectory.id != file.parentId else { return }
        let frozenParent = file.parent?.freezeIfNeeded()
        let frozenFile = file.freezeIfNeeded()
        Task {
            do {
                let (cancelResponse, _) = try await driveFileManager.move(file: frozenFile, to: destinationDirectory)
                UIConstants.showCancelableSnackBar(
                    message: KDriveResourcesStrings.Localizable.fileListMoveFileConfirmationSnackbar(1, destinationDirectory.name),
                    cancelSuccessMessage: KDriveResourcesStrings.Localizable.allFileMoveCancelled,
                    cancelableResponse: cancelResponse,
                    parentFile: frozenParent,
                    driveFileManager: driveFileManager)
                completion?(true)
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
                completion?(false)
            }
        }
    }

    public static func save(file: File, from viewController: UIViewController) {
        switch file.convertedType {
        case .image:
            if let image = UIImage(contentsOfFile: file.localUrl.path) {
                Task {
                    do {
                        try await PhotoLibrarySaver.instance.save(image: image)
                        DispatchQueue.main.async {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarImageSavedConfirmation)
                        }
                    } catch {
                        DDLogError("Cannot save image: \(error)")
                        DispatchQueue.main.async {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSave)
                        }
                    }
                }
            }
        case .video:
            Task {
                do {
                    try await PhotoLibrarySaver.instance.save(videoUrl: file.localUrl)
                    DispatchQueue.main.async {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarVideoSavedConfirmation)
                    }
                } catch {
                    DDLogError("Cannot save video: \(error)")
                    DispatchQueue.main.async {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSave)
                    }
                }
            }
        case .folder:
            let documentExportViewController = UIDocumentPickerViewController(url: file.temporaryUrl, in: .exportToService)
            viewController.present(documentExportViewController, animated: true)
        default:
            let documentExportViewController = UIDocumentPickerViewController(url: file.localUrl, in: .exportToService)
            viewController.present(documentExportViewController, animated: true)
        }
    }

    // MARK: - Single file or multiselection

    public static func favorite(files: [File], driveFileManager: DriveFileManager, completion: ((File) async -> Void)? = nil) async throws -> Bool {
        let areFilesFavorites = files.allSatisfy(\.isFavorite)
        let isFavored = !areFilesFavorites
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in files where file.capabilities.canUseFavorite {
                group.addTask { [frozenFile = file.freezeIfNeeded()] in
                    try await driveFileManager.setFavorite(file: frozenFile, favorite: isFavored)
                    await completion?(file)
                }
            }
            try await group.waitForAll()
        }

        return isFavored
    }
}
