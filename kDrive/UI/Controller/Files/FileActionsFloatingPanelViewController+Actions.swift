/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import InfomaniakDI
import kDriveCore
import kDriveResources
import LinkPresentation
import Sentry
import UIKit

extension FileActionsFloatingPanelViewController {
    // MARK: Setup

    func setupContent() {
        setupQuickActions()
        setupActions()
    }

    private func setupQuickActions() {
        let offline = ReachabilityListener.instance.currentStatus == .offline

        if driveFileManager.isPublicShare {
            quickActions = []
        } else if file.isDirectory {
            quickActions = FloatingPanelAction.folderQuickActions
        } else {
            quickActions = FloatingPanelAction.quickActions
        }

        for action in quickActions {
            switch action {
            case .shareAndRights:
                if !file.capabilities.canShare || offline {
                    action.isEnabled = false
                }
            case .shareLink:
                if (!file.capabilities.canBecomeSharelink || offline) && !file.hasSharelink && !file.isDropbox {
                    action.isEnabled = false
                }
            case .add:
                if !file.capabilities.canCreateFile || !file.capabilities.canCreateDirectory {
                    action.isEnabled = false
                }
            default:
                break
            }
        }
    }

    private func setupActions() {
        guard !driveFileManager.isPublicShare else {
            if file.isDirectory {
                actions = FloatingPanelAction.publicShareFolderActions
            } else {
                actions = FloatingPanelAction.publicShareActions
            }
            return
        }

        actions = (file.isDirectory ? FloatingPanelAction.folderListActions : FloatingPanelAction.listActions).filter { action in
            switch action {
            case .openWith:
                return file.capabilities.canWrite
            case .edit:
                return file.isOfficeFile && file.capabilities.canWrite
            case .manageCategories:
                return driveFileManager.drive.categoryRights.canPutOnFile && !file.isDisabled
            case .favorite:
                return file.capabilities.canUseFavorite
            case .convertToDropbox:
                return file.capabilities.canBecomeDropbox
            case .manageDropbox:
                return file.isDropbox
            case .upsaleColor:
                return file.isDirectory && driveFileManager.drive.isFreePack
            case .folderColor:
                return file.capabilities.canColor
            case .seeFolder:
                return !normalFolderHierarchy && (file.parent != nil || file.parentId != 0)
            case .offline:
                return !sharedWithMe && presentationOrigin != .photoList
            case .download:
                return file.capabilities.canRead
            case .move:
                return file.capabilities.canMove && !sharedWithMe
            case .duplicate:
                return !sharedWithMe && file.capabilities.canRead && file.visibility != .isSharedSpace && file
                    .visibility != .isTeamSpace
            case .rename:
                return file.capabilities.canRename && !sharedWithMe && !file.isImporting
            case .delete:
                return file.capabilities.canDelete && !file.isImporting
            case .leaveShare:
                return file.capabilities.canLeave
            case .cancelImport:
                return file.isImporting
            default:
                return true
            }
        }
    }

    // MARK: Handling

    func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        switch action {
        case .informations:
            informationsAction()
        case .add:
            addAction()
        case .sendCopy:
            sendCopyAction(action, at: indexPath)
        case .shareAndRights:
            shareAndRightsAction()
        case .shareLink:
            shareLinkAction(action, at: indexPath)
        case .openWith:
            openWithAction(action, at: indexPath)
        case .edit:
            OnlyOfficeViewController.open(driveFileManager: driveFileManager, file: file, viewController: self)
        case .manageCategories:
            manageCategoriesAction()
        case .favorite:
            manageFavoriteAction()
        case .convertToDropbox:
            convertToDropboxAction()
        case .manageDropbox:
            manageDropboxAction()
        case .upsaleColor:
            upsaleColorAction()
        case .folderColor:
            folderColorAction()
        case .seeFolder:
            seeFolderAction()
        case .offline:
            offlineAction(at: indexPath)
        case .download:
            downloadAction(action, at: indexPath)
        case .move:
            moveAction()
        case .duplicate:
            duplicateAction()
        case .rename:
            renameAction()
        case .delete:
            deleteAction()
        case .leaveShare:
            leaveShareAction()
        case .cancelImport:
            cancelImportAction()
        case .addToMyDrive:
            addToMyDrive()
        default:
            break
        }
    }

    private func informationsAction() {
        let fileDetailViewController = FileDetailViewController.instantiate(driveFileManager: driveFileManager, file: file)
        presentingParent?.navigationController?.pushViewController(fileDetailViewController, animated: true)
        dismiss(animated: true)
    }

    private func addAction() {
        let floatingPanelViewController = AdaptiveDriveFloatingPanelController()
        let fileInformationsViewController = PlusButtonFloatingPanelViewController(driveFileManager: driveFileManager,
                                                                                   folder: file,
                                                                                   presentedFromPlusButton: false)
        floatingPanelViewController.isRemovalInteractionEnabled = true
        floatingPanelViewController.delegate = fileInformationsViewController

        floatingPanelViewController.set(contentViewController: fileInformationsViewController)
        floatingPanelViewController.track(scrollView: fileInformationsViewController.tableView)
        dismiss(animated: true) {
            self.presentingParent?.present(floatingPanelViewController, animated: true)
        }
    }

    private func sendCopyAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        if file.isMostRecentDownloaded {
            presentShareSheet(from: indexPath)
        } else {
            downloadFile(action: action,
                         indexPath: indexPath) { [weak self] in
                self?.presentShareSheet(from: indexPath)
            }
        }
    }

    private func shareAndRightsAction() {
        let shareVC = ShareAndRightsViewController.instantiate(driveFileManager: driveFileManager, file: file)
        presentingParent?.navigationController?.pushViewController(shareVC, animated: true)
        dismiss(animated: true)
    }

    private func shareLinkAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        if let link = file.dropbox?.url {
            // Copy share link
            copyShareLinkToPasteboard(from: indexPath, link: link)
        } else if let link = file.sharelink?.url {
            // Copy share link
            copyShareLinkToPasteboard(from: indexPath, link: link)
        } else {
            // Create share link
            setLoading(true, action: action, at: indexPath)
            Task { [proxyFile = file.proxify()] in
                do {
                    let shareLink = try await driveFileManager.createShareLink(for: proxyFile)
                    setLoading(false, action: action, at: indexPath)
                    copyShareLinkToPasteboard(from: indexPath, link: shareLink.url)
                } catch {
                    if let error = error as? DriveError, error == .shareLinkAlreadyExists {
                        // This should never happen
                        let shareLink = try? await driveFileManager.apiFetcher.shareLink(for: proxyFile)
                        setLoading(false, action: action, at: indexPath)
                        if let shareLink {
                            driveFileManager.setFileShareLink(file: proxyFile, shareLink: shareLink)
                            copyShareLinkToPasteboard(from: indexPath, link: shareLink.url)
                        }
                    } else {
                        setLoading(false, action: action, at: indexPath)
                        UIConstants.showSnackBarIfNeeded(error: error)
                    }
                }
            }
        }
    }

    private func openWithAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        let view = collectionView.cellForItem(at: indexPath)?.frame ?? .zero
        if file.isMostRecentDownloaded {
            FileActionsHelper.instance.openWith(file: file, from: view, in: collectionView, delegate: self)
        } else {
            downloadFile(action: action, indexPath: indexPath) { [weak self] in
                guard let self else { return }
                FileActionsHelper.instance.openWith(file: file, from: view, in: collectionView, delegate: self)
            }
        }
    }

    private func manageCategoriesAction() {
        FileActionsHelper.manageCategories(
            frozenFiles: [file.freezeIfNeeded()],
            driveFileManager: driveFileManager,
            from: self,
            presentingParent: presentingViewController
        )
    }

    private func manageFavoriteAction() {
        Task {
            do {
                let isFavored = try await FileActionsHelper.favorite(files: [file], driveFileManager: driveFileManager)
                if isFavored {
                    UIConstants
                        .showSnackBar(message: KDriveResourcesStrings.Localizable.fileListAddFavoritesConfirmationSnackbar(1))
                } else {
                    UIConstants
                        .showSnackBar(message: KDriveResourcesStrings.Localizable
                            .fileListRemoveFavoritesConfirmationSnackbar(1))
                }
            } catch {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorAddFavorite)
            }
        }
    }

    private func convertToDropboxAction() {
        guard file.capabilities.canBecomeDropbox else {
            let driveFloatingPanelController = DropBoxFloatingPanelViewController.instantiatePanel()
            let floatingPanelViewController = driveFloatingPanelController
                .contentViewController as? DropBoxFloatingPanelViewController
            floatingPanelViewController?.rightButton.isEnabled = driveFileManager.drive.accountAdmin
            floatingPanelViewController?.actionHandler = { [weak self] _ in
                driveFloatingPanelController.dismiss(animated: true) {
                    guard let self else { return }
                    self.router.presentUpSaleSheet()
                }
            }
            present(driveFloatingPanelController, animated: true)
            return
        }

        if packId == .myKSuite, driveFileManager.drive.dropboxQuotaExceeded {
            router.presentUpSaleSheet()
            return
        }

        let viewController = ManageDropBoxViewController.instantiate(
            driveFileManager: driveFileManager,
            convertingFolder: true,
            folder: file
        )

        presentingParent?.navigationController?.pushViewController(viewController, animated: true)
        dismiss(animated: true)
    }

    private func manageDropboxAction() {
        let viewController = ManageDropBoxViewController.instantiate(driveFileManager: driveFileManager, folder: file)
        presentingParent?.navigationController?.pushViewController(viewController, animated: true)
        dismiss(animated: true)
    }

    private func upsaleColorAction() {
        FileActionsHelper.upsaleFolderColor()
    }

    private func folderColorAction() {
        FileActionsHelper.folderColor(
            files: [file],
            driveFileManager: driveFileManager,
            from: self,
            presentingParent: presentingParent
        ) { isSuccess in
            if isSuccess {
                UIConstants
                    .showSnackBar(message: KDriveResourcesStrings.Localizable.fileListColorFolderConfirmationSnackbar(1))
            }
        }
    }

    private func seeFolderAction() {
        guard let viewController = presentingParent else { return }
        FilePresenter.presentParent(of: file, driveFileManager: driveFileManager, viewController: viewController)
        dismiss(animated: true)
    }

    private func offlineAction(at indexPath: IndexPath) {
        FileActionsHelper.offline(files: [file], driveFileManager: driveFileManager, filesNotAvailable: nil) { _, error in
            if let error {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
        collectionView.reloadItems(at: [IndexPath(item: 0, section: 0), indexPath])
    }

    private func downloadAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        if file.isMostRecentDownloaded {
            FileActionsHelper.save(file: file, from: self)
        } else if let operation = DownloadQueue.instance.operation(for: file.id) {
            // Download is already scheduled, ask to cancel
            let alert = AlertTextViewController(
                title: KDriveResourcesStrings.Localizable.cancelDownloadTitle,
                message: KDriveResourcesStrings.Localizable.cancelDownloadDescription,
                action: KDriveResourcesStrings.Localizable.buttonYes,
                destructive: true
            ) {
                operation.cancel()
            }
            present(alert, animated: true)
        } else {
            downloadFile(action: action, indexPath: indexPath) { [weak self, file] in
                guard let file else { return }
                FileActionsHelper.save(file: file, from: self)
            }
        }
    }

    private func moveAction() {
        let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(
            driveFileManager: driveFileManager,
            startDirectory: file.parent?.freeze(),
            fileToMove: file.id,
            disabledDirectoriesSelection: [file.parent ?? driveFileManager.getCachedRootFile()]
        ) { [weak self] selectedFolder in
            guard let self else { return }
            FileActionsHelper.instance.move(file: file, to: selectedFolder, driveFileManager: driveFileManager) { success in
                // Close preview
                if success,
                   self.presentingParent is PreviewViewController {
                    self.presentingParent?.navigationController?.popViewController(animated: true)
                }
            }
        }
        present(selectFolderNavigationController, animated: true)
    }

    private func duplicateAction() {
        guard file.isManagedByRealm else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
            return
        }
        let fileName = file.name
        let alert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonDuplicate,
                                             placeholder: KDriveResourcesStrings.Localizable.fileInfoInputDuplicateFile,
                                             text: fileName,
                                             action: KDriveResourcesStrings.Localizable.buttonCopy,
                                             loading: true) { [proxyFile = file.proxify()] duplicateName in
            do {
                _ = try await self.driveFileManager.duplicate(file: proxyFile, duplicateName: duplicateName)
                UIConstants
                    .showSnackBar(message: KDriveResourcesStrings.Localizable.fileListDuplicationConfirmationSnackbar(1))
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
        alert.textFieldConfiguration = .fileNameConfiguration
        if !file.isDirectory {
            alert.textFieldConfiguration.selectedRange = fileName
                .startIndex ..< (fileName.lastIndex { $0 == "." } ?? fileName.endIndex)
        }
        present(alert, animated: true)
    }

    private func renameAction() {
        guard file.isManagedByRealm else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
            return
        }
        let placeholder = file.isDirectory ? KDriveResourcesStrings.Localizable.hintInputDirName : KDriveResourcesStrings
            .Localizable.hintInputFileName
        let alert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonRename,
                                             placeholder: placeholder, text: file.name,
                                             action: KDriveResourcesStrings.Localizable.buttonSave,
                                             loading: true) { [proxyFile = file.proxify(), filename = file.name] newName in
            guard newName != filename else { return }
            do {
                _ = try await self.driveFileManager.rename(file: proxyFile, newName: newName)
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
        alert.textFieldConfiguration = .fileNameConfiguration
        if !file.isDirectory {
            alert.textFieldConfiguration.selectedRange = file.name
                .startIndex ..< (file.name.lastIndex { $0 == "." } ?? file.name.endIndex)
        }
        present(alert, animated: true)
    }

    private func deleteAction() {
        guard file.isManagedByRealm else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
            return
        }
        let attrString = NSMutableAttributedString(
            string: KDriveResourcesStrings.Localizable.modalMoveTrashDescription(file.name),
            boldText: file.name
        )
        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalMoveTrashTitle,
                                            message: attrString,
                                            action: KDriveResourcesStrings.Localizable.buttonMove,
                                            destructive: true,
                                            loading: true) { [
            proxyFile = file.proxify(),
            filename = file.name,
            proxyParent = file.parent?.proxify()
        ] in
            do {
                let response = try await self.driveFileManager.delete(file: proxyFile)
                if let presentingParent = self.presentingParent {
                    // Update file list
                    try await (presentingParent as? FileListViewController)?.viewModel.loadActivities()
                    // Close preview
                    if presentingParent is PreviewViewController {
                        presentingParent.navigationController?.popViewController(animated: true)
                    }
                    // Dismiss panel
                    self.dismiss(animated: true)
                    presentingParent.dismiss(animated: true)
                }
                // Show snackbar
                UIConstants.showCancelableSnackBar(
                    message: KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(filename),
                    cancelSuccessMessage: KDriveResourcesStrings.Localizable.allTrashActionCancelled,
                    cancelableResponse: response,
                    parentFile: proxyParent,
                    driveFileManager: self.driveFileManager
                )
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
        present(alert, animated: true)
    }

    private func leaveShareAction() {
        guard file.isManagedByRealm else {
            UIConstants.showSnackBarIfNeeded(error: DriveError.unknownError)
            return
        }
        let attrString = NSMutableAttributedString(
            string: KDriveResourcesStrings.Localizable.modalLeaveShareDescription(file.name),
            boldText: file.name
        )
        let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalLeaveShareTitle,
                                            message: attrString,
                                            action: KDriveResourcesStrings.Localizable.buttonLeaveShare,
                                            loading: true) { [proxyFile = file.proxify()] in
            do {
                _ = try await self.driveFileManager.delete(file: proxyFile)
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarLeaveShareConfirmation)
                self.presentingParent?.navigationController?.popViewController(animated: true)
                self.dismiss(animated: true)
            } catch {
                UIConstants.showSnackBarIfNeeded(error: error)
            }
        }
        present(alert, animated: true)
    }

    private func cancelImportAction() {
        guard let importId = file.externalImport?.id else { return }
        Task {
            do {
                _ = try await driveFileManager.apiFetcher.cancelImport(drive: driveFileManager.drive, id: importId)
                // Dismiss panel
                self.dismiss(animated: true)
            } catch {
                UIConstants.showSnackBar(message: error.localizedDescription)
            }
        }
    }

    private func addToMyDrive() {
        guard accountManager.currentAccount != nil else {
            dismiss(animated: true) {
                self.router.showUpsaleFloatingPanel()
            }
            return
        }

        guard let currentUserDriveFileManager = accountManager.currentDriveFileManager,
              let publicShareProxy = driveFileManager.publicShareProxy else {
            return
        }

        PublicShareAction().addToMyDrive(
            publicShareProxy: publicShareProxy,
            currentUserDriveFileManager: currentUserDriveFileManager,
            selectedItemsIds: [file.id],
            exceptItemIds: [],
            onPresentViewController: { saveNavigationViewController, animated in
                self.present(saveNavigationViewController, animated: animated, completion: nil)
            },
            onSave: {
                MatomoUtils.trackAddToMyDrive()
            },
            onDismissViewController: { [weak self] in
                guard let self else { return }
                self.dismiss(animated: true)
            }
        )
    }
}
