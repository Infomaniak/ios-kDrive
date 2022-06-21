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
import InfomaniakCore
import kDriveCore
import kDriveResources
import Photos
import UIKit

@MainActor
public class FileActionsHelper {
    public static let instance = FileActionsHelper()

    private var interactionController: UIDocumentInteractionController!

    // MARK: - Single file

    public func openWith(file: File, from rect: CGRect, in view: UIView, delegate: UIDocumentInteractionControllerDelegate) {
        guard let rootFolderURL = DriveFileManager.constants.openInPlaceDirectoryURL else {
            DDLogError("Open in place directory not found")
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
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
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
        }
    }

    public func move(file: File, to destinationDirectory: File, driveFileManager: DriveFileManager, completion: ((Bool) -> Void)? = nil) {
        guard destinationDirectory.id != file.parentId else { return }
        Task { [proxyFile = file.proxify(),
                proxyParent = file.parent?.proxify(),
                proxyDestination = destinationDirectory.proxify(),
                destinationName = destinationDirectory.name] in
                do {
                    let (cancelResponse, _) = try await driveFileManager.move(file: proxyFile, to: proxyDestination)
                    UIConstants.showCancelableSnackBar(
                        message: KDriveResourcesStrings.Localizable.fileListMoveFileConfirmationSnackbar(1, destinationName),
                        cancelSuccessMessage: KDriveResourcesStrings.Localizable.allFileMoveCancelled,
                        cancelableResponse: cancelResponse,
                        parentFile: proxyParent,
                        driveFileManager: driveFileManager
                    )
                    completion?(true)
                } catch {
                    UIConstants.showSnackBarIfNeeded(error: error)
                    completion?(false)
                }
        }
    }

    #if !ISEXTENSION
    public static func save(file: File, from viewController: UIViewController? = nil, showSuccessSnackBar: Bool = true) {
        let presenterViewController = viewController != nil
            ? viewController
            : (UIApplication.shared.delegate as! AppDelegate).topMostViewController
        guard presenterViewController as? UIDocumentPickerViewController == nil else { return }
        switch file.convertedType {
        case .image:
            saveMedia(
                url: file.localUrl,
                type: .image,
                successMessage: showSuccessSnackBar ? KDriveResourcesStrings.Localizable.snackbarImageSavedConfirmation : nil
            )
        case .video:
            saveMedia(
                url: file.localUrl,
                type: .video,
                successMessage: showSuccessSnackBar ? KDriveResourcesStrings.Localizable.snackbarVideoSavedConfirmation : nil
            )
        case .folder:
            let documentExportViewController = UIDocumentPickerViewController(url: file.temporaryUrl, in: .exportToService)
            presenterViewController?.present(documentExportViewController, animated: true)
        default:
            let documentExportViewController = UIDocumentPickerViewController(url: file.localUrl, in: .exportToService)
            presenterViewController?.present(documentExportViewController, animated: true)
        }
    }

    private static func saveMedia(url: URL, type: PHAssetMediaType, successMessage: String?) {
        Task {
            do {
                try await PhotoLibrarySaver.instance.save(url: url, type: type)
                if let successMessage = successMessage {
                    UIConstants.showSnackBar(message: successMessage)
                }
            } catch let error as DriveError where error == .photoLibraryWriteAccessDenied {
                UIConstants.showSnackBar(message: error.localizedDescription,
                                         action: .init(title: KDriveResourcesStrings.Localizable.buttonSnackBarGoToSettings) {
                                             guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
                                                   UIApplication.shared.canOpenURL(settingsURL) else { return }
                                             UIApplication.shared.open(settingsURL)
                                         })
            } catch {
                DDLogError("Cannot save media: \(error)")
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSave)
            }
        }
    }
    #endif

    // MARK: - MultipleSelection

    public static func performAndObserve(bulkAction: BulkAction,
                                  observer: AnyObject,
                                  driveFileManager: DriveFileManager,
                                  currentDirectory: File,
                                  completion: () -> Void) async {
        do {
            completion()
            let (actionId, progressSnackBar) = try await FileActionsHelper.perform(bulkAction: bulkAction,
                                                                                   driveFileManager: driveFileManager,
                                                                                   currentDirectory: currentDirectory)
            FileActionsHelper.observeAction(observer: observer,
                                            id: actionId,
                                            ofType: bulkAction.action,
                                            using: progressSnackBar,
                                            driveFileManager: driveFileManager,
                                            currentDirectory: currentDirectory)
        } catch {
            DDLogError("Error while performing bulk action: \(error)")
        }
    }

    private static func perform(bulkAction: BulkAction, driveFileManager: DriveFileManager, currentDirectory: File) async throws -> (actionId: String, snackBar: IKSnackBar?) {
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
                                                               parentFile: currentDirectory.proxify(),
                                                               driveFileManager: driveFileManager)
        return (cancelableResponse.id, progressSnack)
    }

    private static func observeAction(observer: AnyObject, id: String, ofType actionType: BulkActionType, using progressSnack: IKSnackBar?, driveFileManager: DriveFileManager, currentDirectory: File) {
        AccountManager.instance.mqService.observeActionProgress(observer, actionId: id) { actionProgress in
            Task {
                switch actionProgress.progress.message {
                case .starting:
                    break
                case .processing:
                    switch actionType {
                    case .trash:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListDeletionInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                    case .move:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListMoveInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                    case .copy:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListCopyInProgressSnackbar(actionProgress.progress.total - actionProgress.progress.todo, actionProgress.progress.total)
                    }
                    FileActionsHelper.loadActivitiesForCurrentDirectory(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
                case .done:
                    switch actionType {
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
                    FileActionsHelper.loadActivitiesForCurrentDirectory(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
                case .canceled:
                    let message: String
                    switch actionType {
                    case .trash:
                        message = KDriveResourcesStrings.Localizable.allTrashActionCancelled
                    case .move:
                        message = KDriveResourcesStrings.Localizable.allFileMoveCancelled
                    case .copy:
                        message = KDriveResourcesStrings.Localizable.allFileDuplicateCancelled
                    }
                    UIConstants.showSnackBar(message: message)
                    FileActionsHelper.loadActivitiesForCurrentDirectory(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
                }
            }
        }
    }

    private static func loadActivitiesForCurrentDirectory(driveFileManager: DriveFileManager, currentDirectory: File) {
        Task {
            _ = try await driveFileManager.fileActivities(file: currentDirectory.proxify())
            driveFileManager.notifyObserversWith(file: currentDirectory)
        }
    }

    // MARK: - Single file or multiselection

    public static func favorite(files: [File], driveFileManager: DriveFileManager, completion: ((File) async -> Void)? = nil) async throws -> Bool {
        let areFilesFavorites = files.allSatisfy(\.isFavorite)
        let areFavored = !areFilesFavorites
        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in files where file.capabilities.canUseFavorite {
                group.addTask { [proxyFile = file.proxify()] in
                    try await driveFileManager.setFavorite(file: proxyFile, favorite: areFavored)
                    await completion?(file)
                }
            }
            try await group.waitForAll()
        }

        return areFavored
    }

    public static func manageCategories(files: [File], driveFileManager: DriveFileManager, from viewController: UIViewController,
                                        group: DispatchGroup? = nil, presentingParent: UIViewController?, fromMultiselect: Bool = false) {
        group?.enter()
        let navigationManageCategoriesViewController = ManageCategoriesViewController.instantiateInNavigationController(files: files, driveFileManager: driveFileManager)
        let manageCategoriesViewController = (navigationManageCategoriesViewController.topViewController as? ManageCategoriesViewController)
        manageCategoriesViewController?.fileListViewController = presentingParent as? FileListViewController
        manageCategoriesViewController?.fromMultiselect = fromMultiselect
        manageCategoriesViewController?.completionHandler = {
            group?.leave()
        }
        viewController.present(navigationManageCategoriesViewController, animated: true)
    }

    #if !ISEXTENSION

    public static func offline(files: [File], driveFileManager: DriveFileManager, group: DispatchGroup? = nil,
                               filesNotAvailable: (() -> Void)?, completion: @escaping (File, Error?) -> Void) -> Bool {
        let areAvailableOffline = files.allSatisfy(\.isAvailableOffline)
        let makeFilesAvailableOffline = !areAvailableOffline
        if makeFilesAvailableOffline {
            filesNotAvailable?()
            // Update offline files before setting new file to synchronize them
            (UIApplication.shared.delegate as? AppDelegate)?.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
        }

        for file in files where !file.isDirectory && file.isAvailableOffline == areAvailableOffline {
            group?.enter()
            driveFileManager.setFileAvailableOffline(file: file, available: makeFilesAvailableOffline) { error in
                completion(file, error)
                group?.leave()
            }
        }

        return makeFilesAvailableOffline
    }

    public static func folderColor(files: [File], driveFileManager: DriveFileManager, from viewController: UIViewController,
                                   presentingParent: UIViewController?, group: DispatchGroup? = nil, completion: @escaping (Bool) -> Void) {
        group?.enter()
        if driveFileManager.drive.pack == .free {
            let driveFloatingPanelController = FolderColorFloatingPanelViewController.instantiatePanel()
            let floatingPanelViewController = driveFloatingPanelController.contentViewController as? FolderColorFloatingPanelViewController
            floatingPanelViewController?.rightButton.isEnabled = driveFileManager.drive.accountAdmin
            floatingPanelViewController?.actionHandler = { _ in
                driveFloatingPanelController.dismiss(animated: true) {
                    StorePresenter.showStore(from: viewController, driveFileManager: driveFileManager)
                }
            }
            viewController.present(driveFloatingPanelController, animated: true)
        } else {
            let colorSelectionFloatingPanelViewController = ColorSelectionFloatingPanelViewController(files: files, driveFileManager: driveFileManager)
            let floatingPanelViewController = DriveFloatingPanelController()
            floatingPanelViewController.isRemovalInteractionEnabled = true
            floatingPanelViewController.set(contentViewController: colorSelectionFloatingPanelViewController)
            floatingPanelViewController.track(scrollView: colorSelectionFloatingPanelViewController.collectionView)
            colorSelectionFloatingPanelViewController.floatingPanelController = floatingPanelViewController
            colorSelectionFloatingPanelViewController.completionHandler = { isSuccess in
                completion(isSuccess)
                group?.leave()
            }
            viewController.dismiss(animated: true) {
                presentingParent?.present(floatingPanelViewController, animated: true)
            }
        }
    }

    #endif
}
