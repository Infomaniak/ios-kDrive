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

import InfomaniakCore
import kDriveCore
import Sentry
import UIKit

public class FloatingPanelAction: Equatable {
    let id: Int
    let name: String
    var reverseName: String?
    let image: UIImage
    var tintColor: UIColor = KDriveAsset.iconColor.color
    var isLoading = false
    var isEnabled = true

    init(id: Int, name: String, reverseName: String? = nil, image: UIImage, tintColor: UIColor = KDriveAsset.iconColor.color) {
        self.id = id
        self.name = name
        self.reverseName = reverseName
        self.image = image
        self.tintColor = tintColor
    }

    func reset() -> FloatingPanelAction {
        isEnabled = true
        isLoading = false
        return self
    }

    static let openWith = FloatingPanelAction(id: 0, name: KDriveStrings.Localizable.buttonOpenWith, image: KDriveAsset.openWith.image)
    static let edit = FloatingPanelAction(id: 1, name: KDriveStrings.Localizable.buttonEdit, image: KDriveAsset.editDocument.image)
    static let favorite = FloatingPanelAction(id: 2, name: KDriveStrings.Localizable.buttonAddFavorites, reverseName: KDriveStrings.Localizable.buttonRemoveFavorites, image: KDriveAsset.favorite.image)
    static let convertToDropbox = FloatingPanelAction(id: 3, name: KDriveStrings.Localizable.buttonConvertToDropBox, image: KDriveAsset.folderDropBox1.image)
    static let manageDropbox = FloatingPanelAction(id: 4, name: KDriveStrings.Localizable.buttonManageDropBox, image: KDriveAsset.folderDropBox1.image)
    static let seeFolder = FloatingPanelAction(id: 5, name: KDriveStrings.Localizable.buttonSeeFolder, image: KDriveAsset.folderFill.image)
    static let offline = FloatingPanelAction(id: 6, name: KDriveStrings.Localizable.buttonAvailableOffline, image: KDriveAsset.availableOffline.image)
    static let download = FloatingPanelAction(id: 7, name: KDriveStrings.Localizable.buttonDownload, image: KDriveAsset.download.image)
    static let move = FloatingPanelAction(id: 8, name: KDriveStrings.Localizable.buttonMoveTo, image: KDriveAsset.folderSelect.image)
    static let duplicate = FloatingPanelAction(id: 9, name: KDriveStrings.Localizable.buttonDuplicate, image: KDriveAsset.duplicate.image)
    static let rename = FloatingPanelAction(id: 10, name: KDriveStrings.Localizable.buttonRename, image: KDriveAsset.edit.image)
    static let delete = FloatingPanelAction(id: 11, name: KDriveStrings.Localizable.modalMoveTrashTitle, image: KDriveAsset.delete.image, tintColor: KDriveAsset.binColor.color)
    static let leaveShare = FloatingPanelAction(id: 12, name: KDriveStrings.Localizable.buttonLeaveShare, image: KDriveAsset.linkBroken.image)

    static var listActions: [FloatingPanelAction] {
        return [openWith, edit, favorite, seeFolder, offline, download, move, duplicate, rename, delete, leaveShare].map { $0.reset() }
    }

    static var folderListActions: [FloatingPanelAction] {
        return [favorite, convertToDropbox, manageDropbox, seeFolder, download, move, duplicate, rename, delete, leaveShare].map { $0.reset() }
    }

    static let informations = FloatingPanelAction(id: 13, name: KDriveStrings.Localizable.fileDetailsInfosTitle, image: KDriveAsset.info.image)
    static let add = FloatingPanelAction(id: 14, name: KDriveStrings.Localizable.buttonAdd, image: KDriveAsset.add.image)
    static let sendCopy = FloatingPanelAction(id: 15, name: KDriveStrings.Localizable.buttonSendCopy, image: KDriveAsset.exportIos.image)
    static let shareAndRights = FloatingPanelAction(id: 16, name: KDriveStrings.Localizable.buttonFileRights, image: KDriveAsset.share.image)
    static let shareLink = FloatingPanelAction(id: 17, name: KDriveStrings.Localizable.buttonCreatePublicLink, reverseName: KDriveStrings.Localizable.buttonCopyPublicLink, image: KDriveAsset.link.image)

    static var quickActions: [FloatingPanelAction] {
        return [informations, sendCopy, shareAndRights, shareLink].map { $0.reset() }
    }

    static var folderQuickActions: [FloatingPanelAction] {
        return [informations, add, shareAndRights, shareLink].map { $0.reset() }
    }

    static var multipleSelectionActions: [FloatingPanelAction] {
        return [offline, favorite, download].map { $0.reset() }
    }

    static var multipleSelectionSharedWithMeActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    public static func == (lhs: FloatingPanelAction, rhs: FloatingPanelAction) -> Bool {
        return lhs.id == rhs.id
    }
}

protocol FileActionDelegate: AnyObject {
    func didSelectAction(_ action: FloatingPanelAction)
}

class FileQuickActionsFloatingPanelViewController: UITableViewController {
    var driveFileManager: DriveFileManager!
    private(set) var file: File!
    var sharedWithMe: Bool {
        return driveFileManager?.drive.sharedWithMe ?? false
    }

    var normalFolderHierarchy = true
    weak var presentingParent: UIViewController?
    private var listActions = FloatingPanelAction.listActions
    private var quickActions = FloatingPanelAction.quickActions
    private var downloadAction: FloatingPanelAction?
    private var fileObserver: ObservationToken?
    private var downloadObserver: ObservationToken?
    private var interactionController: UIDocumentInteractionController!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorStyle = .none
        tableView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        tableView.register(cellView: FloatingPanelTableViewCell.self)
        tableView.register(cellView: FloatingPanelTitleTableViewCell.self)
        tableView.register(cellView: FloatingPanelCollectionTableViewCell.self)

        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] _ in
            DispatchQueue.main.async {
                guard file != nil else { return }
                file.realm?.refresh()
                if file.isInvalidated {
                    // File has been removed
                    dismiss(animated: true)
                } else {
                    setupContent()
                    UIView.transition(with: tableView, duration: 0.35, options: .transitionCrossDissolve) {
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            // Reload collection view
            if self.tableView.numberOfSections > 1 {
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .fade)
            }
        }
    }

    func setFile(_ newFile: File, driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager

        var newFile = newFile
        if newFile.realm == nil || newFile.isFrozen {
            if let file = driveFileManager.getCachedFile(id: newFile.id, freeze: false) {
                newFile = file
            } else {
                SentrySDK.capture(message: "Got a file that doesn't exist in Realm in FileQuickActionsFloatingPanelViewController!")
            }
        }
        if file == nil || file != newFile {
            file = newFile
            fileObserver?.cancel()
            fileObserver = driveFileManager.observeFileUpdated(self, fileId: file.id) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.file.realm?.refresh()
                    if self?.file.isInvalidated ?? false {
                        // File has been removed
                        self?.dismiss(animated: true)
                    } else {
                        self?.tableView.reloadData()
                    }
                }
            }
            setupContent()
            UIView.transition(with: tableView,
                              duration: 0.35,
                              options: .transitionCrossDissolve) { self.tableView.reloadData() }
        }
    }

    func setupContent() {
        quickActions = file.isDirectory ? FloatingPanelAction.folderQuickActions : FloatingPanelAction.quickActions
        quickActions.forEach { action in
            let offline = ReachabilityListener.instance.currentStatus == .offline
            switch action {
            case .shareAndRights:
                if !(file.rights?.share ?? false) || offline {
                    action.isEnabled = false
                }
            case .shareLink:
                if (!(file.rights?.canBecomeLink ?? false) || offline) && file.shareLink == nil && file.visibility != .isCollaborativeFolder {
                    action.isEnabled = false
                }
            case .add:
                if !(file.rights?.createNewFile ?? false) || !(file.rights?.createNewFolder ?? false) {
                    action.isEnabled = false
                }
            default:
                break
            }
        }

        listActions = (file.isDirectory ? FloatingPanelAction.folderListActions : FloatingPanelAction.listActions).filter { action -> Bool in
            switch action {
            case .openWith:
                return file.rights?.write ?? false
            case .edit:
                return file.isOfficeFile && (file.rights?.write ?? false)
            case .favorite:
                return (file.rights?.canFavorite ?? false) && !sharedWithMe
            case .convertToDropbox:
                return (file.rights?.canBecomeCollab ?? false) && file.shareLink == nil
            case .manageDropbox:
                return file.visibility == .isCollaborativeFolder
            case .seeFolder:
                return !normalFolderHierarchy && (file.parent != nil || file.parentId != 0)
            case .offline:
                return !sharedWithMe
            case .download:
                return file.rights?.read ?? false
            case .move:
                return (file.rights?.move ?? false) && !sharedWithMe
            case .duplicate:
                return !sharedWithMe && (file.rights?.read ?? false) && file.visibility != .isSharedSpace && file.visibility != .isTeamSpace
            case .rename:
                return (file.rights?.rename ?? false) && !sharedWithMe
            case .delete:
                return file.rights?.delete ?? false
            case .leaveShare:
                return file.rights?.leave ?? false
            default:
                return true
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 {
            return listActions.count
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return 222
        } else if indexPath.section == 0 {
            return UIConstants.floatingPanelHeaderHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(type: FloatingPanelTitleTableViewCell.self, for: indexPath)
            cell.configureWith(file: file)
            return cell
        } else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(type: FloatingPanelCollectionTableViewCell.self, for: indexPath)
            cell.delegate = self
            cell.menu = quickActions
            cell.file = file
            cell.collectionView.reloadData()
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(type: FloatingPanelTableViewCell.self, for: indexPath)
            let action = listActions[indexPath.row]
            cell.titleLabel.text = action.name
            cell.accessoryImageView.image = action.image
            cell.accessoryImageView.tintColor = action.tintColor

            if action == .favorite && file.isFavorite {
                cell.titleLabel.text = action.reverseName
                cell.accessoryImageView.tintColor = KDriveAsset.favoriteColor.color
            } else if action == .offline {
                cell.configureAvailableOffline(with: file)
            } else {
                // Show download progress in cells
                if let downloadAction = downloadAction, downloadAction == action {
                    cell.observeProgress(true, file: file)
                } else {
                    cell.observeProgress(false, file: file)
                }
            }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 {
            let action = listActions[indexPath.row]
            handleAction(action, at: indexPath)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    private func refreshFileAndRows(oldFile: File, rows: [IndexPath], animated: Bool = true) {
        guard let newFile = driveFileManager.getCachedFile(id: oldFile.id) else {
            return
        }
        file = newFile
        tableView.reloadRows(at: rows, with: animated ? .fade : .none)
    }

    // swiftlint:disable cyclomatic_complexity
    private func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        guard file.realm != nil else {
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
            return
        }

        switch action {
        case .convertToDropbox:
            if driveFileManager.drive.pack == .free || driveFileManager.drive.pack == .solo {
                let floatingPanelViewController = DropBoxFloatingPanelViewController.instantiatePanel()
                (floatingPanelViewController.contentViewController as? DropBoxFloatingPanelViewController)?.actionHandler = { [weak self] _ in
                    guard let self = self else { return }
                    UIConstants.openUrl("\(ApiRoutes.orderDrive())/\(self.driveFileManager.drive.id)", from: self)
                }
                present(floatingPanelViewController, animated: true)
                return
            } else {
                let viewController = ManageDropBoxViewController.instantiate()
                viewController.driveFileManager = driveFileManager
                viewController.convertingFolder = true
                viewController.folder = file
                presentingParent?.navigationController?.pushViewController(viewController, animated: true)
            }
            dismiss(animated: true)
        case .manageDropbox:
            let viewController = ManageDropBoxViewController.instantiate()
            viewController.driveFileManager = driveFileManager
            viewController.folder = file
            presentingParent?.navigationController?.pushViewController(viewController, animated: true)
            dismiss(animated: true)
        case .openWith:
            if file.isDownloaded && !file.isLocalVersionOlderThanRemote() {
                do {
                    try presentInteractionControllerForCurrentFile(indexPath)
                } catch {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                }
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    do {
                        try self?.presentInteractionControllerForCurrentFile(indexPath)
                    } catch {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                    }
                }
            }
        case .edit:
            OnlyOfficeViewController.open(driveFileManager: driveFileManager, file: file, viewController: self)
        case .favorite:
            driveFileManager.setFavoriteFile(file: file, favorite: !file.isFavorite) { error in
                if error == nil {
                    if !self.file.isFavorite {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileListAddFavorisConfirmationSnackbar(1))
                    }
                    self.refreshFileAndRows(oldFile: self.file, rows: [indexPath, IndexPath(row: 0, section: 0)])
                } else {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorAddFavorite)
                }
            }
        case .seeFolder:
            guard let viewController = presentingParent else { return }
            let filePresenter = FilePresenter(viewController: viewController, floatingPanelViewController: nil)
            filePresenter.presentParent(of: file, driveFileManager: driveFileManager)
            dismiss(animated: true)
        case .rename:
            let file = self.file.freeze()
            let placeholder = file.isDirectory ? KDriveStrings.Localizable.hintInputDirName : KDriveStrings.Localizable.hintInputFileName
            let alert = AlertFieldViewController(title: KDriveStrings.Localizable.buttonRename, placeholder: placeholder, text: file.name, action: KDriveStrings.Localizable.buttonSave, loading: true) { newName in
                if newName != file.name {
                    let group = DispatchGroup()
                    var success = false
                    group.enter()
                    self.driveFileManager.renameFile(file: file, newName: newName) { _, error in
                        if error == nil {
                            success = true
                        }
                        group.leave()
                    }
                    _ = group.wait(timeout: .now() + Constants.timeout)
                    DispatchQueue.main.async {
                        if success {
                            self.refreshFileAndRows(oldFile: self.file, rows: [indexPath, IndexPath(row: 0, section: 0)])
                        } else {
                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorRename)
                        }
                    }
                }
            }
            alert.textFieldConfiguration = .fileNameConfiguration
            if !file.isDirectory {
                alert.textFieldConfiguration.selectedRange = file.name.startIndex..<(file.name.lastIndex(where: { $0 == "." }) ?? file.name.endIndex)
            }
            present(alert, animated: true)
        case .delete:
            let attrString = NSMutableAttributedString(string: KDriveStrings.Localizable.modalMoveTrashDescription(file.name), boldText: file.name)
            let file = self.file.freeze()
            let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalMoveTrashTitle, message: attrString, action: KDriveStrings.Localizable.buttonMove, destructive: true, loading: true) {
                let group = DispatchGroup()
                var success = false
                var cancelId: String?
                group.enter()
                self.driveFileManager.deleteFile(file: file) { response, error in
                    success = error == nil
                    cancelId = response?.id
                    group.leave()
                }
                _ = group.wait(timeout: .now() + Constants.timeout)
                DispatchQueue.main.async {
                    if success {
                        let group = DispatchGroup()
                        if let presentingParent = self.presentingParent {
                            // Update file list
                            (presentingParent as? FileListViewController)?.getNewChanges()
                            // Close preview
                            if presentingParent is PreviewViewController {
                                presentingParent.navigationController?.popViewController(animated: true)
                            }
                            // Dismiss panel
                            group.enter()
                            self.dismiss(animated: true) {
                                group.leave()
                            }
                            group.enter()
                            presentingParent.dismiss(animated: true) {
                                group.leave()
                            }
                        }
                        // Show snackbar (wait for panel dismissal)
                        group.notify(queue: .main) {
                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarMoveTrashConfirmation(file.name), action: .init(title: KDriveStrings.Localizable.buttonCancel) {
                                if let cancelId = cancelId {
                                    self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                        if error == nil {
                                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.allTrashActionCancelled)
                                        }
                                    }
                                }
                            })
                        }
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorDelete)
                    }
                }
            }
            present(alert, animated: true)
        case .download:
            if file.isDownloaded && !file.isLocalVersionOlderThanRemote() {
                saveLocalFile(file: file)
                tableView.reloadRows(at: [indexPath], with: .fade)
            } else if let operation = DownloadQueue.instance.operation(for: file) {
                // Download is already scheduled, ask to cancel
                let alert = AlertTextViewController(title: KDriveStrings.Localizable.cancelDownloadTitle, message: KDriveStrings.Localizable.cancelDownloadDescription, action: KDriveStrings.Localizable.buttonYes, destructive: true) {
                    operation.cancel()
                }
                present(alert, animated: true)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [unowned self] in
                    saveLocalFile(file: file)
                }
            }
        case .offline:
            if !file.isAvailableOffline {
                // Update offline files before setting new file to synchronize them
                (UIApplication.shared.delegate as? AppDelegate)?.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
            }
            driveFileManager.setFileAvailableOffline(file: file, available: !file.isAvailableOffline) { error in
                if error != nil {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorCache)
                }
                self.refreshFileAndRows(oldFile: self.file, rows: [indexPath, IndexPath(row: 0, section: 0)], animated: false)
            }
            refreshFileAndRows(oldFile: file, rows: [indexPath, IndexPath(row: 0, section: 0)])
        case .duplicate:
            let file = self.file.freeze()
            let pathString = self.file.name as NSString
            let text = KDriveStrings.Localizable.allDuplicateFileName(pathString.deletingPathExtension, pathString.pathExtension.isEmpty ? "" : ".\(pathString.pathExtension)")
            let alert = AlertFieldViewController(title: KDriveStrings.Localizable.buttonDuplicate, placeholder: KDriveStrings.Localizable.fileInfoInputDuplicateFile, text: text, action: KDriveStrings.Localizable.buttonCopy, loading: true) { duplicateName in
                if duplicateName != file.name {
                    let group = DispatchGroup()
                    var success = false
                    group.enter()
                    self.driveFileManager.duplicateFile(file: file, duplicateName: duplicateName) { _, error in
                        if error == nil {
                            success = true
                        }
                        group.leave()
                    }
                    _ = group.wait(timeout: .now() + Constants.timeout)
                    DispatchQueue.main.async {
                        if success {
                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileListDuplicationConfirmationSnackbar(1))
                            self.refreshFileAndRows(oldFile: self.file, rows: [indexPath, IndexPath(row: 0, section: 0)])
                        } else {
                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorDuplicate)
                        }
                    }
                }
            }
            alert.textFieldConfiguration = .fileNameConfiguration
            if !file.isDirectory {
                alert.textFieldConfiguration.selectedRange = text.startIndex..<(text.lastIndex(where: { $0 == "." }) ?? text.endIndex)
            }
            present(alert, animated: true)
        case .move:
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager)
            let selectFolderViewController = selectFolderNavigationController.topViewController as? SelectFolderViewController
            selectFolderViewController?.disabledDirectoriesSelection = [file.parent ?? driveFileManager.getRootFile()]
            selectFolderViewController?.fileToMove = file.id
            selectFolderViewController?.selectHandler = { [unowned self] selectedFolder in
                self.driveFileManager.moveFile(file: self.file, newParent: selectedFolder) { response, _, error in
                    if error != nil {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorMove)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileListMoveFileConfirmationSnackbar(1, selectedFolder.name), action: .init(title: KDriveStrings.Localizable.buttonCancel) {
                            if let cancelId = response?.id {
                                self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                    if error == nil {
                                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.allFileMoveCancelled)
                                    }
                                }
                            }
                        })
                        self.presentingParent?.navigationController?.popViewController(animated: true)
                    }
                }
            }
            present(selectFolderNavigationController, animated: true)
            tableView.reloadRows(at: [indexPath], with: .fade)
        case .leaveShare:
            let attrString = NSMutableAttributedString(string: KDriveStrings.Localizable.modalLeaveShareDescription(file.name), boldText: file.name)
            let file = self.file.freeze()
            let alert = AlertTextViewController(title: KDriveStrings.Localizable.modalLeaveShareTitle, message: attrString, action: KDriveStrings.Localizable.buttonLeaveShare, loading: true) {
                let group = DispatchGroup()
                var success = false
                group.enter()
                self.driveFileManager.deleteFile(file: file) { _, error in
                    success = error == nil
                    group.leave()
                }
                _ = group.wait(timeout: .now() + Constants.timeout)
                DispatchQueue.main.async {
                    if success {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarLeaveShareConfirmation)
                        self.presentingParent?.navigationController?.popViewController(animated: true)
                        self.dismiss(animated: true)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorLeaveShare)
                    }
                }
            }
            present(alert, animated: true)
        case .informations:
            let fileDetailViewController = FileDetailViewController.instantiate()
            fileDetailViewController.file = file
            presentingParent?.navigationController?.pushViewController(fileDetailViewController, animated: true)
            dismiss(animated: true)
        case .shareAndRights:
            let shareVC = ShareAndRightsViewController.instantiate()
            shareVC.file = file
            shareVC.driveFileManager = driveFileManager
            presentingParent?.navigationController?.pushViewController(shareVC, animated: true)
            dismiss(animated: true)
        case .add:
            #if !ISEXTENSION
                let floatingPanelViewController = DriveFloatingPanelController()
                let fileInformationsViewController = PlusButtonFloatingPanelViewController()
                fileInformationsViewController.driveFileManager = driveFileManager
                fileInformationsViewController.currentDirectory = file
                floatingPanelViewController.isRemovalInteractionEnabled = true
                floatingPanelViewController.delegate = fileInformationsViewController

                floatingPanelViewController.set(contentViewController: fileInformationsViewController)
                floatingPanelViewController.track(scrollView: fileInformationsViewController.tableView)
                dismiss(animated: true) {
                    self.presentingParent?.present(floatingPanelViewController, animated: true)
                }
            #endif
        case .sendCopy:
            var source: UIView = tableView!
            if let cell = (tableView.cellForRow(at: indexPath) as? FloatingPanelCollectionTableViewCell),
               let index = cell.menu.firstIndex(of: .sendCopy),
               let quickActionCell = cell.collectionView.cellForItem(at: IndexPath(row: index, section: 0)) {
                source = quickActionCell
            }
            if file.isDownloaded && !file.isLocalVersionOlderThanRemote() {
                presentShareSheetForCurrentFile(sender: source)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    self?.presentShareSheetForCurrentFile(sender: source)
                }
            }
        case .shareLink:
            if file.visibility == .isCollaborativeFolder {
                // Copy drop box link
                action.isLoading = true
                tableView.reloadSections([1], with: .none)
                driveFileManager.apiFetcher.getDropBoxSettings(directory: file) { response, _ in
                    action.isLoading = false
                    self.tableView.reloadSections([1], with: .none)
                    if let dropBox = response?.data {
                        self.copyShareLinkToPasteboard(link: dropBox.url)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
                    }
                }
            } else if let link = file.shareLink {
                // Copy share link
                copyShareLinkToPasteboard(link: link)
            } else {
                // Create share link
                action.isLoading = true
                tableView.reloadSections([1], with: .none)
                driveFileManager.activateShareLink(for: file) { newFile, shareLink, error in
                    if let newFile = newFile, let link = shareLink {
                        self.file = newFile
                        action.isLoading = false
                        self.tableView.reloadSections([1], with: .none)
                        self.copyShareLinkToPasteboard(link: link.url)
                    } else if let error = error as? DriveError, error == .shareLinkAlreadyExists {
                        // This should never happen
                        self.driveFileManager.apiFetcher.getShareListFor(file: self.file) { response, _ in
                            if let data = response?.data, let link = data.link?.url {
                                if let newFile = self.driveFileManager.setFileShareLink(file: self.file, shareLink: link)?.freeze() {
                                    self.file = newFile
                                }
                                self.copyShareLinkToPasteboard(link: link)
                            }
                            action.isLoading = false
                            self.tableView.reloadSections([1], with: .none)
                        }
                    } else {
                        action.isLoading = false
                        self.tableView.reloadSections([1], with: .none)
                        UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveStrings.Localizable.errorShareLink)
                    }
                }
            }
        default:
            break
        }
    }

    private func downloadFile(action: FloatingPanelAction, indexPath: IndexPath, completion: @escaping () -> Void) {
        action.isLoading = true
        downloadAction = action
        tableView.reloadRows(at: [indexPath], with: .fade)
        downloadObserver?.cancel()
        downloadObserver = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { [unowned self] _, error in
            action.isLoading = false
            downloadAction = nil
            DispatchQueue.main.async {
                if error == nil {
                    completion()
                } else if error != .taskCancelled && error != .taskRescheduled {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorDownload)
                }
                refreshFileAndRows(oldFile: file, rows: [indexPath])
            }
        }
        DownloadQueue.instance.addToQueue(file: file)
    }

    private func copyShareLinkToPasteboard(link: String) {
        DispatchQueue.main.async {
            UIPasteboard.general.url = URL(string: link)
            UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileInfoLinkCopiedToClipboard)
        }
    }

    func saveLocalFile(file: File) {
        switch file.convertedType {
        case .image:
            if let image = UIImage(contentsOfFile: file.localUrl.path) {
                PhotoLibrarySaver.instance.save(image: image) { success, _ in
                    DispatchQueue.main.async {
                        if success {
                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarImageSavedConfirmation)
                        } else {
                            UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorSave)
                        }
                    }
                }
            }
        case .video:
            PhotoLibrarySaver.instance.save(videoUrl: file.localUrl) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.snackbarVideoSavedConfirmation)
                    } else {
                        UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorSave)
                    }
                }
            }
        case .folder:
            DispatchQueue.main.async { [weak self] in
                let documentExportViewController = UIDocumentPickerViewController(url: file.temporaryUrl, in: .exportToService)
                self?.present(documentExportViewController, animated: true)
            }
        default:
            DispatchQueue.main.async { [weak self] in
                let documentExportViewController = UIDocumentPickerViewController(url: file.localUrl, in: .exportToService)
                self?.present(documentExportViewController, animated: true)
            }
        }
    }

    private func presentShareSheetForCurrentFile(sender: UIView) {
        let activityViewController = UIActivityViewController(activityItems: [file.localUrl], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = sender
        present(activityViewController, animated: true, completion: nil)
    }

    private func presentInteractionControllerForCurrentFile(_ indexPath: IndexPath) throws {
        guard let rootFolderURL = DriveFileManager.constants.openInPlaceDirectoryURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)
        }
        // Create directory if needed
        let folderURL = rootFolderURL.appendingPathComponent("\(file.driveId)", isDirectory: true).appendingPathComponent("\(file.id)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        // Copy file
        let fileUrl = folderURL.appendingPathComponent(file.name)
        var shouldCopy = true
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileUrl.path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
            if file.lastModifiedDate > modificationDate {
                try FileManager.default.removeItem(at: fileUrl)
            } else {
                shouldCopy = false
            }
        }
        if shouldCopy {
            try FileManager.default.copyItem(at: file.localUrl, to: fileUrl)
        }
        // Create document interaction controller
        interactionController = UIDocumentInteractionController(url: fileUrl)
        interactionController.delegate = self
        let view = tableView.cellForRow(at: indexPath)?.frame ?? .zero
        // Present document interaction controller
        interactionController.presentOpenInMenu(from: view, in: tableView, animated: true)
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(driveFileManager.drive.id, forKey: "DriveId")
        coder.encode(file.id, forKey: "FileId")
        coder.encode(normalFolderHierarchy, forKey: "NormalFolderHierarchy")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveId")
        let fileId = coder.decodeInteger(forKey: "FileId")
        normalFolderHierarchy = coder.decodeBool(forKey: "NormalFolderHierarchy")
        guard let driveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId) else {
            return
        }
        self.driveFileManager = driveFileManager
        file = driveFileManager.getCachedFile(id: fileId)
        // Update UI
        setupContent()
        UIView.transition(with: tableView, duration: 0.35, options: .transitionCrossDissolve) {
            self.tableView.reloadData()
        }
    }
}

// MARK: FileActionDelegate

extension FileQuickActionsFloatingPanelViewController: FileActionDelegate {
    func didSelectAction(_ action: FloatingPanelAction) {
        handleAction(action, at: IndexPath(row: 0, section: 1))
    }
}

// MARK: Document interaction controller delegate

extension FileQuickActionsFloatingPanelViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
        // Dismiss interaction controller when the user taps an app
        controller.dismissMenu(animated: true)
    }
}
