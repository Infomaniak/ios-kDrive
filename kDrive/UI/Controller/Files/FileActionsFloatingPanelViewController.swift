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
import Sentry
import UIKit

public class FloatingPanelAction: Equatable {
    let id: Int
    let name: String
    var reverseName: String?
    let image: UIImage
    var tintColor: UIColor = KDriveResourcesAsset.iconColor.color
    var isLoading = false
    var isEnabled = true

    init(id: Int, name: String, reverseName: String? = nil, image: UIImage, tintColor: UIColor = KDriveResourcesAsset.iconColor.color) {
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

    static let openWith = FloatingPanelAction(id: 0, name: KDriveResourcesStrings.Localizable.buttonOpenWith, image: KDriveResourcesAsset.openWith.image)
    static let edit = FloatingPanelAction(id: 1, name: KDriveResourcesStrings.Localizable.buttonEdit, image: KDriveResourcesAsset.editDocument.image)
    static let manageCategories = FloatingPanelAction(id: 2, name: KDriveResourcesStrings.Localizable.manageCategoriesTitle, image: KDriveResourcesAsset.categories.image)
    static let favorite = FloatingPanelAction(id: 3, name: KDriveResourcesStrings.Localizable.buttonAddFavorites, reverseName: KDriveResourcesStrings.Localizable.buttonRemoveFavorites, image: KDriveResourcesAsset.favorite.image)
    static let convertToDropbox = FloatingPanelAction(id: 4, name: KDriveResourcesStrings.Localizable.buttonConvertToDropBox, image: KDriveResourcesAsset.folderDropBox1.image)
    static let manageDropbox = FloatingPanelAction(id: 5, name: KDriveResourcesStrings.Localizable.buttonManageDropBox, image: KDriveResourcesAsset.folderDropBox1.image)
    static let seeFolder = FloatingPanelAction(id: 6, name: KDriveResourcesStrings.Localizable.buttonSeeFolder, image: KDriveResourcesAsset.folderFill.image)
    static let offline = FloatingPanelAction(id: 7, name: KDriveResourcesStrings.Localizable.buttonAvailableOffline, image: KDriveResourcesAsset.availableOffline.image)
    static let download = FloatingPanelAction(id: 8, name: KDriveResourcesStrings.Localizable.buttonDownload, image: KDriveResourcesAsset.download.image)
    static let move = FloatingPanelAction(id: 9, name: KDriveResourcesStrings.Localizable.buttonMoveTo, image: KDriveResourcesAsset.folderSelect.image)
    static let duplicate = FloatingPanelAction(id: 10, name: KDriveResourcesStrings.Localizable.buttonDuplicate, image: KDriveResourcesAsset.duplicate.image)
    static let rename = FloatingPanelAction(id: 11, name: KDriveResourcesStrings.Localizable.buttonRename, image: KDriveResourcesAsset.edit.image)
    static let delete = FloatingPanelAction(id: 12, name: KDriveResourcesStrings.Localizable.modalMoveTrashTitle, image: KDriveResourcesAsset.delete.image, tintColor: KDriveResourcesAsset.binColor.color)
    static let leaveShare = FloatingPanelAction(id: 13, name: KDriveResourcesStrings.Localizable.buttonLeaveShare, image: KDriveResourcesAsset.linkBroken.image)

    static var listActions: [FloatingPanelAction] {
        return [openWith, edit, manageCategories, favorite, seeFolder, offline, download, move, duplicate, rename, delete, leaveShare].map { $0.reset() }
    }

    static var folderListActions: [FloatingPanelAction] {
        return [manageCategories, favorite, convertToDropbox, manageDropbox, seeFolder, download, move, duplicate, rename, delete, leaveShare].map { $0.reset() }
    }

    static let informations = FloatingPanelAction(id: 14, name: KDriveResourcesStrings.Localizable.fileDetailsInfosTitle, image: KDriveResourcesAsset.info.image)
    static let add = FloatingPanelAction(id: 15, name: KDriveResourcesStrings.Localizable.buttonAdd, image: KDriveResourcesAsset.add.image)
    static let sendCopy = FloatingPanelAction(id: 16, name: KDriveResourcesStrings.Localizable.buttonSendCopy, image: KDriveResourcesAsset.exportIos.image)
    static let shareAndRights = FloatingPanelAction(id: 17, name: KDriveResourcesStrings.Localizable.buttonFileRights, image: KDriveResourcesAsset.share.image)
    static let shareLink = FloatingPanelAction(id: 18, name: KDriveResourcesStrings.Localizable.buttonCreatePublicLink, reverseName: KDriveResourcesStrings.Localizable.buttonCopyPublicLink, image: KDriveResourcesAsset.link.image)

    static var quickActions: [FloatingPanelAction] {
        return [informations, sendCopy, shareAndRights, shareLink].map { $0.reset() }
    }

    static var folderQuickActions: [FloatingPanelAction] {
        return [informations, add, shareAndRights, shareLink].map { $0.reset() }
    }

    static var multipleSelectionActions: [FloatingPanelAction] {
        return [offline, favorite, download, duplicate].map { $0.reset() }
    }

    static var multipleSelectionSharedWithMeActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var multipleSelectionBulkActions: [FloatingPanelAction] {
        return [download, duplicate].map { $0.reset() }
    }

    public static func == (lhs: FloatingPanelAction, rhs: FloatingPanelAction) -> Bool {
        return lhs.id == rhs.id
    }
}

class FileActionsFloatingPanelViewController: UICollectionViewController {
    var driveFileManager: DriveFileManager!
    var file: File!
    var normalFolderHierarchy = true
    weak var presentingParent: UIViewController?

    var sharedWithMe: Bool {
        return driveFileManager?.drive.sharedWithMe ?? false
    }

    enum Section: CaseIterable {
        case header, quickActions, actions
    }

    class var sections: [Section] {
        return Section.allCases
    }

    var quickActions = FloatingPanelAction.quickActions
    var actions = FloatingPanelAction.listActions

    private var downloadAction: FloatingPanelAction?
    private var fileObserver: ObservationToken?
    private var downloadObserver: ObservationToken?
    private var interactionController: UIDocumentInteractionController!

    // MARK: - Public methods

    convenience init() {
        self.init(collectionViewLayout: FileActionsFloatingPanelViewController.createLayout())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FloatingPanelQuickActionCollectionViewCell.self)
        collectionView.register(cellView: FloatingPanelActionCollectionViewCell.self)
        collectionView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        collectionView.dragDelegate = self

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.file != nil else { return }
                self?.file.realm?.refresh()
                if self?.file.isInvalidated == true {
                    // File has been removed
                    self?.dismiss(animated: true)
                } else {
                    self?.reload(animated: true)
                }
            }
        }
    }

    func setFile(_ newFile: File, driveFileManager: DriveFileManager) {
        self.driveFileManager = driveFileManager

        // Try to get a live File
        var newFile = newFile
        if !newFile.isManagedByRealm || newFile.isFrozen {
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
                DispatchQueue.main.async {
                    self?.file.realm?.refresh()
                    if self?.file.isInvalidated == true {
                        // File has been removed
                        self?.dismiss(animated: true)
                    } else {
                        self?.reload(animated: true)
                    }
                }
            }
            // Reload
            reload(animated: false)
        }
    }

    // MARK: - Private methods

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            switch sections[section] {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(UIConstants.fileListCellHeight))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            case .quickActions:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
                group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)
                return NSCollectionLayoutSection(group: group)
            case .actions:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(53))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
        }
    }

    internal func setupContent() {
        let offline = ReachabilityListener.instance.currentStatus == .offline

        quickActions = file.isDirectory ? FloatingPanelAction.folderQuickActions : FloatingPanelAction.quickActions
        quickActions.forEach { action in
            switch action {
            case .shareAndRights:
                if file.rights?.share != true || offline {
                    action.isEnabled = false
                }
            case .shareLink:
                if (file.rights?.canBecomeLink != true || offline) && file.shareLink == nil && file.visibility != .isCollaborativeFolder {
                    action.isEnabled = false
                }
            case .add:
                if file.rights?.createNewFile != true || file.rights?.createNewFolder != true {
                    action.isEnabled = false
                }
            default:
                break
            }
        }

        actions = (file.isDirectory ? FloatingPanelAction.folderListActions : FloatingPanelAction.listActions).filter { action in
            switch action {
            case .openWith:
                return file.rights?.write == true
            case .edit:
                return file.isOfficeFile && file.rights?.write == true
            case .manageCategories:
                return driveFileManager.drive.categoryRights.canPutCategoryOnFile
            case .favorite:
                return file.rights?.canFavorite == true && !sharedWithMe
            case .convertToDropbox:
                return file.rights?.canBecomeCollab == true && file.shareLink == nil
            case .manageDropbox:
                return file.visibility == .isCollaborativeFolder
            case .seeFolder:
                return !normalFolderHierarchy && (file.parent != nil || file.parentId != 0)
            case .offline:
                return !sharedWithMe
            case .download:
                return file.rights?.read == true
            case .move:
                return file.rights?.move == true && !sharedWithMe
            case .duplicate:
                return !sharedWithMe && file.rights?.read == true && file.visibility != .isSharedSpace && file.visibility != .isTeamSpace
            case .rename:
                return file.rights?.rename == true && !sharedWithMe
            case .delete:
                return file.rights?.delete == true
            case .leaveShare:
                return file.rights?.leave == true
            default:
                return true
            }
        }
    }

    private func reload(animated: Bool) {
        setupContent()
        if animated {
            UIView.transition(with: collectionView, duration: 0.35, options: .transitionCrossDissolve) {
                self.collectionView.reloadData()
            }
        } else {
            collectionView.reloadData()
        }
    }

    internal func handleAction(_ action: FloatingPanelAction, at indexPath: IndexPath) {
        switch action {
        case .informations:
            let fileDetailViewController = FileDetailViewController.instantiate(driveFileManager: driveFileManager, file: file)
            fileDetailViewController.file = file
            presentingParent?.navigationController?.pushViewController(fileDetailViewController, animated: true)
            dismiss(animated: true)
        case .add:
            let floatingPanelViewController = DriveFloatingPanelController()
            let fileInformationsViewController = PlusButtonFloatingPanelViewController(driveFileManager: driveFileManager, folder: file)
            floatingPanelViewController.isRemovalInteractionEnabled = true
            floatingPanelViewController.delegate = fileInformationsViewController

            floatingPanelViewController.set(contentViewController: fileInformationsViewController)
            floatingPanelViewController.track(scrollView: fileInformationsViewController.tableView)
            dismiss(animated: true) {
                self.presentingParent?.present(floatingPanelViewController, animated: true)
            }
        case .sendCopy:
            if file.isDownloaded && !file.isLocalVersionOlderThanRemote() {
                presentShareSheet(from: indexPath)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    self?.presentShareSheet(from: indexPath)
                }
            }
        case .shareAndRights:
            let shareVC = ShareAndRightsViewController.instantiate(driveFileManager: driveFileManager, file: file)
            presentingParent?.navigationController?.pushViewController(shareVC, animated: true)
            dismiss(animated: true)
        case .shareLink:
            if file.visibility == .isCollaborativeFolder {
                // Copy drop box link
                setLoading(true, action: action, at: indexPath)
                driveFileManager.apiFetcher.getDropBoxSettings(directory: file) { [weak self] response, _ in
                    self?.setLoading(false, action: action, at: indexPath)
                    if let dropBox = response?.data {
                        self?.copyShareLinkToPasteboard(dropBox.url)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                    }
                }
            } else if let link = file.shareLink {
                // Copy share link
                copyShareLinkToPasteboard(link)
            } else {
                // Create share link
                setLoading(true, action: action, at: indexPath)
                driveFileManager.activateShareLink(for: file) { [weak self] shareLink, error in
                    if let link = shareLink {
                        self?.setLoading(false, action: action, at: indexPath)
                        self?.copyShareLinkToPasteboard(link.url)
                    } else if let error = error as? DriveError, let file = self?.file, error == .shareLinkAlreadyExists {
                        // This should never happen
                        self?.driveFileManager.apiFetcher.getShareListFor(file: file) { response, _ in
                            if let data = response?.data, let link = data.link?.url {
                                _ = self?.driveFileManager.setFileShareLink(file: file, shareLink: link)
                                self?.copyShareLinkToPasteboard(link)
                            }
                            self?.setLoading(false, action: action, at: indexPath)
                        }
                    } else {
                        self?.setLoading(false, action: action, at: indexPath)
                        UIConstants.showSnackBar(message: error?.localizedDescription ?? KDriveResourcesStrings.Localizable.errorShareLink)
                    }
                }
            }
        case .openWith:
            if file.isDownloaded && !file.isLocalVersionOlderThanRemote() {
                presentInteractionController(from: indexPath)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    self?.presentInteractionController(from: indexPath)
                }
            }
        case .edit:
            OnlyOfficeViewController.open(driveFileManager: driveFileManager, file: file, viewController: self)
        case .manageCategories:
            let manageCategoriesViewController = ManageCategoriesViewController.instantiateInNavigationController(file: file, driveFileManager: driveFileManager)
            (manageCategoriesViewController.topViewController as? ManageCategoriesViewController)?.fileListViewController = presentingParent as? FileListViewController
            present(manageCategoriesViewController, animated: true)
        case .favorite:
            driveFileManager.setFavoriteFile(file: file, favorite: !file.isFavorite) { [wasFavorited = file.isFavorite] error in
                if error == nil {
                    if !wasFavorited {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListAddFavorisConfirmationSnackbar(1))
                    }
                } else {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorAddFavorite)
                }
            }
        case .convertToDropbox:
            if driveFileManager.drive.pack == .free || driveFileManager.drive.pack == .solo {
                let driveFloatingPanelController = DropBoxFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController.contentViewController as? DropBoxFloatingPanelViewController
                floatingPanelViewController?.rightButton.isEnabled = driveFileManager.drive.accountAdmin
                floatingPanelViewController?.actionHandler = { [weak self] _ in
                    driveFloatingPanelController.dismiss(animated: true) {
                        guard let self = self else { return }
                        StorePresenter.showStore(from: self, driveFileManager: self.driveFileManager)
                    }
                }
                present(driveFloatingPanelController, animated: true)
            } else {
                let viewController = ManageDropBoxViewController.instantiate(driveFileManager: driveFileManager, convertingFolder: true, folder: file)
                presentingParent?.navigationController?.pushViewController(viewController, animated: true)
                dismiss(animated: true)
            }
        case .manageDropbox:
            let viewController = ManageDropBoxViewController.instantiate(driveFileManager: driveFileManager, folder: file)
            presentingParent?.navigationController?.pushViewController(viewController, animated: true)
            dismiss(animated: true)
        case .seeFolder:
            guard let viewController = presentingParent else { return }
            let filePresenter = FilePresenter(viewController: viewController, floatingPanelViewController: nil)
            filePresenter.presentParent(of: file, driveFileManager: driveFileManager)
            dismiss(animated: true)
        case .offline:
            if !file.isAvailableOffline {
                // Update offline files before setting new file to synchronize them
                (UIApplication.shared.delegate as? AppDelegate)?.updateAvailableOfflineFiles(status: ReachabilityListener.instance.currentStatus)
            }
            driveFileManager.setFileAvailableOffline(file: file, available: !file.isAvailableOffline) { error in
                if error != nil && error as? DriveError != .taskCancelled && error as? DriveError != .taskRescheduled {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorCache)
                }
            }
            collectionView.reloadItems(at: [IndexPath(item: 0, section: 0), indexPath])
        case .download:
            if file.isDownloaded && !file.isLocalVersionOlderThanRemote() {
                saveFile()
            } else if let operation = DownloadQueue.instance.operation(for: file) {
                // Download is already scheduled, ask to cancel
                let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.cancelDownloadTitle, message: KDriveResourcesStrings.Localizable.cancelDownloadDescription, action: KDriveResourcesStrings.Localizable.buttonYes, destructive: true) {
                    operation.cancel()
                }
                present(alert, animated: true)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    self?.saveFile()
                }
            }
        case .move:
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, startDirectory: file.parent, fileToMove: file.id, disabledDirectoriesSelection: [file.parent ?? driveFileManager.getRootFile()]) { [unowned self] selectedFolder in
                self.driveFileManager.moveFile(file: self.file, newParent: selectedFolder) { response, _, error in
                    if error != nil {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorMove)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListMoveFileConfirmationSnackbar(1, selectedFolder.name), action: .init(title: KDriveResourcesStrings.Localizable.buttonCancel) {
                            if let cancelId = response?.id {
                                self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                    if error == nil {
                                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.allFileMoveCancelled)
                                    }
                                }
                            }
                        })
                        // Close preview
                        if self.presentingParent is PreviewViewController {
                            self.presentingParent?.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            }
            present(selectFolderNavigationController, animated: true)
        case .duplicate:
            guard file.isManagedByRealm else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                return
            }
            let file = self.file.freeze()
            let pathString = self.file.name as NSString
            let text = KDriveResourcesStrings.Localizable.allDuplicateFileName(pathString.deletingPathExtension, pathString.pathExtension.isEmpty ? "" : ".\(pathString.pathExtension)")
            let alert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonDuplicate, placeholder: KDriveResourcesStrings.Localizable.fileInfoInputDuplicateFile, text: text, action: KDriveResourcesStrings.Localizable.buttonCopy, loading: true) { duplicateName in
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
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListDuplicationConfirmationSnackbar(1))
                        } else {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDuplicate)
                        }
                    }
                }
            }
            alert.textFieldConfiguration = .fileNameConfiguration
            if !file.isDirectory {
                alert.textFieldConfiguration.selectedRange = text.startIndex ..< (text.lastIndex(where: { $0 == "." }) ?? text.endIndex)
            }
            present(alert, animated: true)
        case .rename:
            guard file.isManagedByRealm else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                return
            }
            let file = self.file.freeze()
            let placeholder = file.isDirectory ? KDriveResourcesStrings.Localizable.hintInputDirName : KDriveResourcesStrings.Localizable.hintInputFileName
            let alert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonRename, placeholder: placeholder, text: file.name, action: KDriveResourcesStrings.Localizable.buttonSave, loading: true) { newName in
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
                        if !success {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorRename)
                        }
                    }
                }
            }
            alert.textFieldConfiguration = .fileNameConfiguration
            if !file.isDirectory {
                alert.textFieldConfiguration.selectedRange = file.name.startIndex ..< (file.name.lastIndex(where: { $0 == "." }) ?? file.name.endIndex)
            }
            present(alert, animated: true)
        case .delete:
            guard file.isManagedByRealm else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                return
            }
            let attrString = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalMoveTrashDescription(file.name), boldText: file.name)
            let file = self.file.freeze()
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalMoveTrashTitle, message: attrString, action: KDriveResourcesStrings.Localizable.buttonMove, destructive: true, loading: true) {
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
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarMoveTrashConfirmation(file.name), action: .init(title: KDriveResourcesStrings.Localizable.buttonCancel) {
                                if let cancelId = cancelId {
                                    self.driveFileManager.cancelAction(cancelId: cancelId) { error in
                                        if error == nil {
                                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.allTrashActionCancelled)
                                        }
                                    }
                                }
                            })
                        }
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDelete)
                    }
                }
            }
            present(alert, animated: true)
        case .leaveShare:
            guard file.isManagedByRealm else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                return
            }
            let attrString = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalLeaveShareDescription(file.name), boldText: file.name)
            let file = self.file.freeze()
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalLeaveShareTitle, message: attrString, action: KDriveResourcesStrings.Localizable.buttonLeaveShare, loading: true) {
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
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarLeaveShareConfirmation)
                        self.presentingParent?.navigationController?.popViewController(animated: true)
                        self.dismiss(animated: true)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorLeaveShare)
                    }
                }
            }
            present(alert, animated: true)
        default:
            break
        }
    }

    private func setLoading(_ isLoading: Bool, action: FloatingPanelAction, at indexPath: IndexPath) {
        action.isLoading = isLoading
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadItems(at: [indexPath])
        }
    }

    private func presentShareSheet(from indexPath: IndexPath) {
        let activityViewController = UIActivityViewController(activityItems: [file.localUrl], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = collectionView.cellForItem(at: indexPath) ?? collectionView
        present(activityViewController, animated: true, completion: nil)
    }

    private func presentInteractionController(from indexPath: IndexPath) {
        guard let rootFolderURL = DriveFileManager.constants.openInPlaceDirectoryURL else {
            DDLogError("Open in place directory not found")
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
            return
        }
        do {
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
            let view = collectionView.cellForItem(at: indexPath)?.frame ?? .zero
            // Present document interaction controller
            interactionController.presentOpenInMenu(from: view, in: collectionView, animated: true)
        } catch {
            DDLogError("Cannot present interaction controller: \(error)")
            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
        }
    }

    private func downloadFile(action: FloatingPanelAction, indexPath: IndexPath, completion: @escaping () -> Void) {
        downloadAction = action
        setLoading(true, action: action, at: indexPath)
        downloadObserver?.cancel()
        downloadObserver = DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { [weak self] _, error in
            self?.downloadAction = nil
            self?.setLoading(true, action: action, at: indexPath)
            DispatchQueue.main.async {
                if error == nil {
                    completion()
                } else if error != .taskCancelled && error != .taskRescheduled {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorDownload)
                }
            }
        }
        DownloadQueue.instance.addToQueue(file: file)
    }

    private func copyShareLinkToPasteboard(_ link: String) {
        UIPasteboard.general.url = URL(string: link)
        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileInfoLinkCopiedToClipboard)
    }

    internal func saveFile() {
        switch file.convertedType {
        case .image:
            if let image = UIImage(contentsOfFile: file.localUrl.path) {
                PhotoLibrarySaver.instance.save(image: image) { success, _ in
                    DispatchQueue.main.async {
                        if success {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarImageSavedConfirmation)
                        } else {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSave)
                        }
                    }
                }
            }
        case .video:
            PhotoLibrarySaver.instance.save(videoUrl: file.localUrl) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.snackbarVideoSavedConfirmation)
                    } else {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorSave)
                    }
                }
            }
        case .folder:
            let documentExportViewController = UIDocumentPickerViewController(url: file.temporaryUrl, in: .exportToService)
            present(documentExportViewController, animated: true)
        default:
            let documentExportViewController = UIDocumentPickerViewController(url: file.localUrl, in: .exportToService)
            present(documentExportViewController, animated: true)
        }
    }

    // MARK: - Collection view data source

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Self.sections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Self.sections[section] {
        case .header:
            return 1
        case .quickActions:
            return quickActions.count
        case .actions:
            return actions.count
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Self.sections[indexPath.section] {
        case .header:
            let cell = collectionView.dequeueReusableCell(type: FileCollectionViewCell.self, for: indexPath)
            cell.configureWith(driveFileManager: driveFileManager, file: file)
            cell.moreButton.isHidden = true
            return cell
        case .quickActions:
            let cell = collectionView.dequeueReusableCell(type: FloatingPanelQuickActionCollectionViewCell.self, for: indexPath)
            let action = quickActions[indexPath.item]
            cell.configure(with: action, file: file)
            return cell
        case .actions:
            let cell = collectionView.dequeueReusableCell(type: FloatingPanelActionCollectionViewCell.self, for: indexPath)
            let action = actions[indexPath.item]
            cell.configure(with: action, file: file, showProgress: downloadAction == action)
            return cell
        }
    }

    // MARK: - Collection view delegate

    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        switch Self.sections[indexPath.section] {
        case .header:
            return false
        case .quickActions:
            return quickActions[indexPath.item].isEnabled
        case .actions:
            return true
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action: FloatingPanelAction
        switch Self.sections[indexPath.section] {
        case .header:
            fatalError("Cannot select header")
        case .quickActions:
            action = quickActions[indexPath.item]
        case .actions:
            action = actions[indexPath.item]
        }
        handleAction(action, at: indexPath)
    }
}

// MARK: - Collection view drag delegate

extension FileActionsFloatingPanelViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard Self.sections[indexPath.section] == .header, file.rights?.move == true && !sharedWithMe else {
            return []
        }

        let dragAndDropFile = DragAndDropFile(file: file, userId: driveFileManager.drive.userId)
        let itemProvider = NSItemProvider(object: dragAndDropFile)
        itemProvider.suggestedName = file.name
        let draggedItem = UIDragItem(itemProvider: itemProvider)
        if let previewImageView = (collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell)?.logoImage {
            draggedItem.previewProvider = {
                UIDragPreview(view: previewImageView)
            }
        }
        return [draggedItem]
    }
}

// MARK: - Document interaction controller delegate

extension FileActionsFloatingPanelViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
        // Dismiss interaction controller when the user taps an app
        controller.dismissMenu(animated: true)
    }
}
