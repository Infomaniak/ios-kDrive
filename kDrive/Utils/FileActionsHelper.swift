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
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import Photos
import UIKit

@MainActor
public final class FileActionsHelper {
    private var interactionController: UIDocumentInteractionController!

    public static let instance = FileActionsHelper()

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
                if file.revisedAt > modificationDate {
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

    public func move(
        file: File,
        to destinationDirectory: File,
        driveFileManager: DriveFileManager,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard destinationDirectory.id != file.parentId else { return }
        Task { [
            proxyFile = file.proxify(),
            proxyParent = file.parent?.proxify(),
            proxyDestination = destinationDirectory.proxify(),
            destinationName = destinationDirectory.name
        ] in
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
        guard !file.isInvalidated else { return }

        @InjectService var appNavigable: AppNavigable
        let presenterViewController = viewController != nil
            ? viewController
            : appNavigable.topMostViewController
        guard presenterViewController as? UIDocumentPickerViewController == nil else { return }

        let convertedType = file.convertedType
        switch convertedType {
        case .image, .video:
            saveMedia(
                url: file.localUrl,
                type: convertedType.assetMediaType,
                successMessage: showSuccessSnackBar ? KDriveResourcesStrings.Localizable.snackbarImageSavedConfirmation : nil
            )
        case .folder:
            let documentExportViewController = UIDocumentPickerViewController(forExporting: [file.temporaryUrl], asCopy: true)
            presenterViewController?.present(documentExportViewController, animated: true)
        default:
            let documentExportViewController = UIDocumentPickerViewController(forExporting: [file.localUrl], asCopy: true)
            presenterViewController?.present(documentExportViewController, animated: true)
        }
    }

    private static func saveMedia(url: URL, type: PHAssetMediaType, successMessage: String?) {
        // TODO: Move code to a dedicated type that will not be pinned to the main thread, so detached will not be needed anymore
        Task.detached {
            do {
                @InjectService var photoLibrarySaver: PhotoLibrarySavable
                try await photoLibrarySaver.save(url: url, type: type)
                if let successMessage {
                    await UIConstants.showSnackBar(message: successMessage)
                }
            } catch let error as DriveError where error == .photoLibraryWriteAccessDenied {
                await UIConstants
                    .showSnackBar(message: error.localizedDescription,
                                  action: .init(title: KDriveResourcesStrings.Localizable.buttonSnackBarGoToSettings) {
                                      Task { @MainActor in
                                          guard let settingsURL = URL(string: UIApplication.openSettingsURLString),
                                                UIApplication.shared.canOpenURL(settingsURL) else { return }
                                          UIApplication.shared.open(settingsURL)
                                      }
                                  })
            } catch {
                if (error as? PHPhotosError)?.code == PHPhotosError.notEnoughSpace {
                    await UIConstants.showSnackBarIfNeeded(error: DriveError.errorDeviceStorage)
                } else {
                    DDLogError("Cannot save media: \(error)")
                    let message = "Failed to save media"
                    let context = ["Underlying Error": error]
                    SentryDebug.capture(message: message, context: context, contextKey: "Error")
                    await UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSave)
                }
            }
        }
    }
    #endif

    // MARK: - Multiple Selection

    public static func move(files: [File],
                            exceptFileIds: [Int],
                            from currentDirectory: File,
                            allItemsSelected: Bool,
                            forceMoveDistinctFiles: Bool = false,
                            observer: AnyObject,
                            driveFileManager: DriveFileManager,
                            presentViewController: (UIViewController) -> Void,
                            completion: (() -> Void)? = nil) {
        // Current directory is always disabled.
        var disabledDirectoriesIds = [currentDirectory.id]
        if let firstSelectedParentId = files.first?.parentId,
           firstSelectedParentId != currentDirectory.id,
           files.allSatisfy({ $0.parentId == firstSelectedParentId }) {
            disabledDirectoriesIds.append(firstSelectedParentId)
        }
        let selectFolderNavigationController = SelectFolderViewController
            .instantiateInNavigationController(driveFileManager: driveFileManager,
                                               startDirectory: currentDirectory,
                                               disabledDirectoriesIdsSelection: disabledDirectoriesIds) { destinationDirectory in
                Task {
                    await moveToDestination(destinationDirectory,
                                            from: currentDirectory,
                                            files: files,
                                            exceptFileIds: exceptFileIds,
                                            allItemsSelected: allItemsSelected,
                                            forceMoveDistinctFiles: forceMoveDistinctFiles,
                                            observer: observer,
                                            driveFileManager: driveFileManager,
                                            completion: completion)
                }
            }
        presentViewController(selectFolderNavigationController)
    }

    // swiftlint:disable:next function_parameter_count
    private static func moveToDestination(_ destinationDirectory: File,
                                          from currentDirectory: File,
                                          files: [File],
                                          exceptFileIds: [Int],
                                          allItemsSelected: Bool,
                                          forceMoveDistinctFiles: Bool = false,
                                          observer: AnyObject,
                                          driveFileManager: DriveFileManager,
                                          completion: (() -> Void)?) async {
        if allItemsSelected && !forceMoveDistinctFiles {
            await bulkMove(exceptFileIds: exceptFileIds,
                           from: currentDirectory,
                           to: destinationDirectory,
                           observer: observer,
                           driveFileManager: driveFileManager,
                           completion: completion)
        } else if files.count > Constants.bulkActionThreshold {
            await bulkMove(files,
                           from: currentDirectory,
                           to: destinationDirectory,
                           observer: observer,
                           driveFileManager: driveFileManager,
                           completion: completion)
        } else {
            do {
                // Move files only if needed
                let proxySelectedItems = files.filter { $0.parentId != destinationDirectory.id }.map { $0.proxify() }
                let proxyDestinationDirectory = destinationDirectory.proxify()
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for proxyFile in proxySelectedItems {
                        group.addTask {
                            _ = try await driveFileManager.move(file: proxyFile, to: proxyDestinationDirectory)
                        }
                    }
                    try await group.waitForAll()
                }
                UIConstants
                    .showSnackBar(message: KDriveResourcesStrings.Localizable
                        .fileListMoveFileConfirmationSnackbar(files.count, destinationDirectory.name))
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
            completion?()
        }
    }

    public static func performAndObserve(bulkAction: BulkAction,
                                         from currentDirectory: File,
                                         observer: AnyObject,
                                         driveFileManager: DriveFileManager,
                                         completion: (() -> Void)?) async {
        do {
            completion?()
            let (actionId, progressSnackBar) = try await perform(bulkAction: bulkAction,
                                                                 driveFileManager: driveFileManager,
                                                                 currentDirectory: currentDirectory)
            observeAction(withId: actionId,
                          ofType: bulkAction.action,
                          from: currentDirectory,
                          using: progressSnackBar,
                          observer: observer,
                          driveFileManager: driveFileManager)
        } catch {
            DDLogError("Error while performing bulk action: \(error)")
        }
    }

    private static func perform(bulkAction: BulkAction, driveFileManager: DriveFileManager,
                                currentDirectory: File) async throws -> (actionId: String, snackBar: IKSnackBar?) {
        let cancelableResponse = try await driveFileManager.apiFetcher.bulkAction(
            drive: driveFileManager.drive,
            action: bulkAction
        )

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

    private static func observeAction(withId actionId: String,
                                      ofType actionType: BulkActionType,
                                      from currentDirectory: File,
                                      using progressSnack: IKSnackBar?,
                                      observer: AnyObject,
                                      driveFileManager: DriveFileManager) {
        @InjectService var accountManager: AccountManageable
        accountManager.mqService.observeActionProgress(observer, actionId: actionId) { actionProgress in
            Task {
                switch actionProgress.progress.message {
                case .starting:
                    break
                case .processing:
                    switch actionType {
                    case .trash:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListDeletionInProgressSnackbar(
                            actionProgress.progress.total - actionProgress.progress.todo,
                            actionProgress.progress.total
                        )
                    case .move:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListMoveInProgressSnackbar(
                            actionProgress.progress.total - actionProgress.progress.todo,
                            actionProgress.progress.total
                        )
                    case .copy:
                        progressSnack?.message = KDriveResourcesStrings.Localizable.fileListCopyInProgressSnackbar(
                            actionProgress.progress.total - actionProgress.progress.todo,
                            actionProgress.progress.total
                        )
                    }
                    loadActivitiesForCurrentDirectory(currentDirectory, driveFileManager: driveFileManager)
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
                    loadActivitiesForCurrentDirectory(currentDirectory, driveFileManager: driveFileManager)
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
                    loadActivitiesForCurrentDirectory(currentDirectory, driveFileManager: driveFileManager)
                }
            }
        }
    }

    private static func loadActivitiesForCurrentDirectory(_ currentDirectory: File, driveFileManager: DriveFileManager) {
        Task {
            _ = try await driveFileManager.fileActivities(file: currentDirectory.proxify())
            driveFileManager.notifyObserversWith(file: currentDirectory)
        }
    }

    // MARK: - Bulk actions

    private static func bulkMove(_ files: [File],
                                 from currentDirectory: File,
                                 to destinationDirectory: File,
                                 observer: AnyObject,
                                 driveFileManager: DriveFileManager,
                                 completion: (() -> Void)?) async {
        let action = BulkAction(action: .move, fileIds: files.map(\.id), destinationDirectoryId: destinationDirectory.id)
        await performAndObserve(bulkAction: action,
                                from: currentDirectory,
                                observer: observer,
                                driveFileManager: driveFileManager,
                                completion: completion)
    }

    private static func bulkMove(exceptFileIds: [Int],
                                 from currentDirectory: File,
                                 to destinationDirectory: File,
                                 observer: AnyObject,
                                 driveFileManager: DriveFileManager,
                                 completion: (() -> Void)? = nil) async {
        let action = BulkAction(
            action: .move,
            parentId: currentDirectory.id,
            exceptFileIds: exceptFileIds,
            destinationDirectoryId: destinationDirectory.id
        )
        await performAndObserve(bulkAction: action,
                                from: currentDirectory,
                                observer: observer,
                                driveFileManager: driveFileManager,
                                completion: completion)
    }

    // MARK: - Single file or multiple selection

    public static func favorite(
        files: [File],
        driveFileManager: DriveFileManager,
        completion: ((File) async -> Void)? = nil
    ) async throws -> Bool {
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

    public static func manageCategories(
        frozenFiles: [File],
        driveFileManager: DriveFileManager,
        from viewController: UIViewController,
        group: DispatchGroup? = nil,
        presentingParent: UIViewController?
    ) {
        group?.enter()
        let navigationManageCategoriesViewController = ManageCategoriesViewController.instantiateInNavigationController(
            frozenFiles: frozenFiles,
            driveFileManager: driveFileManager
        )
        let manageCategoriesViewController = (navigationManageCategoriesViewController
            .topViewController as? ManageCategoriesViewController)
        manageCategoriesViewController?.fileListViewController = presentingParent as? FileListViewController
        manageCategoriesViewController?.completionHandler = {
            group?.leave()
        }
        navigationManageCategoriesViewController.presentationController?.delegate = manageCategoriesViewController
        viewController.present(navigationManageCategoriesViewController, animated: true)
    }

    @discardableResult
    public static func offline(files: [File],
                               driveFileManager: DriveFileManager,
                               group: DispatchGroup? = nil,
                               filesNotAvailable: (() -> Void)?,
                               completion: @escaping (File, Error?) -> Void) -> Bool {
        let onlyFiles = files.filter { !$0.isDirectory }

        let areAvailableOffline = onlyFiles.allSatisfy(\.isAvailableOffline)
        let makeFilesAvailableOffline = !areAvailableOffline
        if makeFilesAvailableOffline {
            filesNotAvailable?()
            // Update offline files before setting new file to synchronize them
            @InjectService var offlineManager: AvailableOfflineManageable
            offlineManager.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
        }

        for file in onlyFiles where file.isAvailableOffline == areAvailableOffline {
            group?.enter()
            driveFileManager.setFileAvailableOffline(file: file, available: makeFilesAvailableOffline) { error in
                completion(file, error)
                group?.leave()
            }
        }

        return makeFilesAvailableOffline
    }

    #if !ISEXTENSION
    public static func folderColor(files: [File], driveFileManager: DriveFileManager,
                                   from viewController: UIViewController,
                                   presentingParent: UIViewController?, group: DispatchGroup? = nil,
                                   completion: @escaping (Bool) -> Void) {
        group?.enter()
        guard !driveFileManager.drive.isFreePack else {
            upsaleFolderColor()
            return
        }

        let colorSelectionFloatingPanelViewController = ColorSelectionFloatingPanelViewController(
            files: files,
            driveFileManager: driveFileManager
        )
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

    public static func upsaleFolderColor() {
        @InjectService var router: AppNavigable
        router.presentUpSaleSheet()
        MatomoUtils.track(eventWithCategory: .myKSuiteUpgradeBottomSheet, name: "colorFolder")
    }
    #endif
}
