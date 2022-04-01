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
    static let convertToDropbox = FloatingPanelAction(id: 4, name: KDriveResourcesStrings.Localizable.buttonConvertToDropBox, image: KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate))
    static let folderColor = FloatingPanelAction(id: 5, name: KDriveResourcesStrings.Localizable.buttonChangeFolderColor, image: KDriveResourcesAsset.colorBucket.image)
    static let manageDropbox = FloatingPanelAction(id: 6, name: KDriveResourcesStrings.Localizable.buttonManageDropBox, image: KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate))
    static let seeFolder = FloatingPanelAction(id: 7, name: KDriveResourcesStrings.Localizable.buttonSeeFolder, image: KDriveResourcesAsset.folderFilled.image.withRenderingMode(.alwaysTemplate))
    static let offline = FloatingPanelAction(id: 8, name: KDriveResourcesStrings.Localizable.buttonAvailableOffline, image: KDriveResourcesAsset.availableOffline.image)
    static let download = FloatingPanelAction(id: 9, name: KDriveResourcesStrings.Localizable.buttonDownload, image: KDriveResourcesAsset.download.image)
    static let move = FloatingPanelAction(id: 10, name: KDriveResourcesStrings.Localizable.buttonMoveTo, image: KDriveResourcesAsset.folderSelect.image)
    static let duplicate = FloatingPanelAction(id: 11, name: KDriveResourcesStrings.Localizable.buttonDuplicate, image: KDriveResourcesAsset.duplicate.image)
    static let rename = FloatingPanelAction(id: 12, name: KDriveResourcesStrings.Localizable.buttonRename, image: KDriveResourcesAsset.edit.image)
    static let delete = FloatingPanelAction(id: 13, name: KDriveResourcesStrings.Localizable.modalMoveTrashTitle, image: KDriveResourcesAsset.delete.image, tintColor: KDriveResourcesAsset.binColor.color)
    static let leaveShare = FloatingPanelAction(id: 14, name: KDriveResourcesStrings.Localizable.buttonLeaveShare, image: KDriveResourcesAsset.linkBroken.image)

    static var listActions: [FloatingPanelAction] {
        return [openWith, edit, manageCategories, favorite, seeFolder, offline, download, move, duplicate, rename, leaveShare, delete].map { $0.reset() }
    }

    static var folderListActions: [FloatingPanelAction] {
        return [manageCategories, favorite, folderColor, convertToDropbox, manageDropbox, seeFolder, download, move, duplicate, rename, leaveShare, delete].map { $0.reset() }
    }

    static let informations = FloatingPanelAction(id: 15, name: KDriveResourcesStrings.Localizable.fileDetailsInfosTitle, image: KDriveResourcesAsset.info.image)
    static let add = FloatingPanelAction(id: 16, name: KDriveResourcesStrings.Localizable.buttonAdd, image: KDriveResourcesAsset.add.image)
    static let sendCopy = FloatingPanelAction(id: 17, name: KDriveResourcesStrings.Localizable.buttonSendCopy, image: KDriveResourcesAsset.exportIos.image)
    static let shareAndRights = FloatingPanelAction(id: 18, name: KDriveResourcesStrings.Localizable.buttonFileRights, image: KDriveResourcesAsset.share.image)
    static let shareLink = FloatingPanelAction(id: 19, name: KDriveResourcesStrings.Localizable.buttonCreatePublicLink, reverseName: KDriveResourcesStrings.Localizable.buttonCopyPublicLink, image: KDriveResourcesAsset.link.image)

    static var quickActions: [FloatingPanelAction] {
        return [informations, sendCopy, shareAndRights, shareLink].map { $0.reset() }
    }

    static var folderQuickActions: [FloatingPanelAction] {
        return [informations, add, shareAndRights, shareLink].map { $0.reset() }
    }

    static var multipleSelectionActions: [FloatingPanelAction] {
        return [manageCategories, favorite, folderColor, offline, download, duplicate].map { $0.reset() }
    }

    static var multipleSelectionSharedWithMeActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var multipleSelectionBulkActions: [FloatingPanelAction] {
        return [offline, download, duplicate].map { $0.reset() }
    }

    static var selectAllActions: [FloatingPanelAction] {
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
    var matomoCategory: MatomoUtils.EventCategory {
        if presentingParent is PhotoListViewController {
            return .picturesFileAction
        }
        return .fileListFileAction
    }

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
        }
        // Reload
        reload(animated: false)
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

        actions = (file.isDirectory ? FloatingPanelAction.folderListActions : FloatingPanelAction.listActions).filter { action in
            switch action {
            case .openWith:
                return file.capabilities.canWrite
            case .edit:
                return file.isOfficeFile && file.capabilities.canWrite
            case .manageCategories:
                return driveFileManager.drive.categoryRights.canPutCategoryOnFile && !file.isDisabled
            case .favorite:
                return file.capabilities.canUseFavorite && !sharedWithMe
            case .convertToDropbox:
                return file.capabilities.canBecomeDropbox
            case .manageDropbox:
                return file.isDropbox
            case .folderColor:
                return !sharedWithMe && file.visibility != .isSharedSpace && file.visibility != .isTeamSpace && !file.isDisabled
            case .seeFolder:
                return !normalFolderHierarchy && (file.parent != nil || file.parentId != 0)
            case .offline:
                return !sharedWithMe
            case .download:
                return file.capabilities.canRead
            case .move:
                return file.capabilities.canMove && !sharedWithMe
            case .duplicate:
                return !sharedWithMe && file.capabilities.canRead && file.visibility != .isSharedSpace && file.visibility != .isTeamSpace
            case .rename:
                return file.capabilities.canRename && !sharedWithMe
            case .delete:
                return file.capabilities.canDelete
            case .leaveShare:
                return file.capabilities.canLeave
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
            let floatingPanelViewController = AdaptiveDriveFloatingPanelController()
            let fileInformationsViewController = PlusButtonFloatingPanelViewController(driveFileManager: driveFileManager,
                                                                                       folder: file, presentedFromPlusButton: false)
            floatingPanelViewController.isRemovalInteractionEnabled = true
            floatingPanelViewController.delegate = fileInformationsViewController

            floatingPanelViewController.set(contentViewController: fileInformationsViewController)
            floatingPanelViewController.track(scrollView: fileInformationsViewController.tableView)
            dismiss(animated: true) {
                self.presentingParent?.present(floatingPanelViewController, animated: true)
            }
        case .sendCopy:
            if file.isMostRecentDownloaded {
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
            if let link = file.dropbox?.url {
                // Copy share link
                copyShareLinkToPasteboard(link)
            } else if let link = file.sharelink?.url {
                // Copy share link
                copyShareLinkToPasteboard(link)
            } else {
                // Create share link
                setLoading(true, action: action, at: indexPath)
                Task { [proxyFile = file.proxify()] in
                    do {
                        let shareLink = try await driveFileManager.createShareLink(for: proxyFile)
                        setLoading(false, action: action, at: indexPath)
                        copyShareLinkToPasteboard(shareLink.url)
                    } catch {
                        if let error = error as? DriveError, error == .shareLinkAlreadyExists {
                            // This should never happen
                            let shareLink = try? await driveFileManager.apiFetcher.shareLink(for: proxyFile)
                            setLoading(false, action: action, at: indexPath)
                            if let shareLink = shareLink {
                                driveFileManager.setFileShareLink(file: proxyFile, shareLink: shareLink)
                                copyShareLinkToPasteboard(shareLink.url)
                            }
                        } else {
                            setLoading(false, action: action, at: indexPath)
                            UIConstants.showSnackBar(message: error.localizedDescription)
                        }
                    }
                }
            }
        case .openWith:
            let view = collectionView.cellForItem(at: indexPath)?.frame ?? .zero
            if file.isMostRecentDownloaded {
                FileActionsHelper.instance.openWith(file: file, from: view, in: collectionView, delegate: self)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    guard let self = self else { return }
                    FileActionsHelper.instance.openWith(file: self.file, from: view, in: self.collectionView, delegate: self)
                }
            }
        case .edit:
            OnlyOfficeViewController.open(driveFileManager: driveFileManager, file: file, viewController: self)
        case .manageCategories:
            FileActionsHelper.manageCategories(files: [file], driveFileManager: driveFileManager, from: self, presentingParent: presentingViewController)
        case .favorite:
            Task {
                do {
                    let isFavored = try await FileActionsHelper.favorite(files: [file], driveFileManager: driveFileManager)
                    if isFavored {
                        UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListAddFavorisConfirmationSnackbar(1))
                    }
                } catch {
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
        case .folderColor:
            FileActionsHelper.folderColor(files: [file], driveFileManager: driveFileManager, from: self, presentingParent: presentingParent) { isSuccess in
                if isSuccess {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListColorFolderConfirmationSnackbar(1))
                }
            }
        case .seeFolder:
            guard let viewController = presentingParent else { return }
            FilePresenter.presentParent(of: file, driveFileManager: driveFileManager, viewController: viewController)
            dismiss(animated: true)
        case .offline:
            FileActionsHelper.offline(files: [file], driveFileManager: driveFileManager, filesNotAvailable: nil) { _, error in
                if error != nil && error as? DriveError != .taskCancelled && error as? DriveError != .taskRescheduled {
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorCache)
                }
            }
            collectionView.reloadItems(at: [IndexPath(item: 0, section: 0), indexPath])
        case .download:
            if file.isMostRecentDownloaded {
                FileActionsHelper.save(file: file, from: self)
            } else if let operation = DownloadQueue.instance.operation(for: file) {
                // Download is already scheduled, ask to cancel
                let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.cancelDownloadTitle, message: KDriveResourcesStrings.Localizable.cancelDownloadDescription, action: KDriveResourcesStrings.Localizable.buttonYes, destructive: true) {
                    operation.cancel()
                }
                present(alert, animated: true)
            } else {
                downloadFile(action: action, indexPath: indexPath) { [weak self] in
                    guard let self = self else { return }
                    if let file = self.file {
                        FileActionsHelper.save(file: file, from: self)
                    }
                }
            }
        case .move:
            let selectFolderNavigationController = SelectFolderViewController.instantiateInNavigationController(driveFileManager: driveFileManager, startDirectory: file.parent?.freeze(), fileToMove: file.id, disabledDirectoriesSelection: [file.parent ?? driveFileManager.getCachedRootFile()]) { [unowned self] selectedFolder in
                FileActionsHelper.instance.move(file: file, to: selectedFolder, driveFileManager: driveFileManager) { success in
                    // Close preview
                    if success,
                       self.presentingParent is PreviewViewController {
                        self.presentingParent?.navigationController?.popViewController(animated: true)
                    }
                }
            }
            present(selectFolderNavigationController, animated: true)
        case .duplicate:
            guard file.isManagedByRealm else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                return
            }
            let pathString = file.name as NSString
            let text = KDriveResourcesStrings.Localizable.allDuplicateFileName(pathString.deletingPathExtension, pathString.pathExtension.isEmpty ? "" : ".\(pathString.pathExtension)")
            let alert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonDuplicate,
                                                 placeholder: KDriveResourcesStrings.Localizable.fileInfoInputDuplicateFile,
                                                 text: text,
                                                 action: KDriveResourcesStrings.Localizable.buttonCopy,
                                                 loading: true) { [proxyFile = file.proxify(), filename = file.name] duplicateName in
                guard duplicateName != filename else { return }
                do {
                    _ = try await self.driveFileManager.duplicate(file: proxyFile, duplicateName: duplicateName)
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.fileListDuplicationConfirmationSnackbar(1))
                } catch {
                    UIConstants.showSnackBar(message: error.localizedDescription)
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
            let placeholder = file.isDirectory ? KDriveResourcesStrings.Localizable.hintInputDirName : KDriveResourcesStrings.Localizable.hintInputFileName
            let alert = AlertFieldViewController(title: KDriveResourcesStrings.Localizable.buttonRename,
                                                 placeholder: placeholder, text: file.name,
                                                 action: KDriveResourcesStrings.Localizable.buttonSave,
                                                 loading: true) { [proxyFile = file.proxify(), filename = file.name] newName in
                guard newName != filename else { return }
                do {
                    _ = try await self.driveFileManager.rename(file: proxyFile, newName: newName)
                } catch {
                    UIConstants.showSnackBar(message: error.localizedDescription)
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
            let alert = AlertTextViewController(title: KDriveResourcesStrings.Localizable.modalMoveTrashTitle,
                                                message: attrString,
                                                action: KDriveResourcesStrings.Localizable.buttonMove,
                                                destructive: true,
                                                loading: true) { [proxyFile = file.proxify(), filename = file.name, proxyParent = file.parent?.proxify()] in
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
                        driveFileManager: self.driveFileManager)
                } catch {
                    UIConstants.showSnackBar(message: error.localizedDescription)
                }
            }
            present(alert, animated: true)
        case .leaveShare:
            guard file.isManagedByRealm else {
                UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorGeneric)
                return
            }
            let attrString = NSMutableAttributedString(string: KDriveResourcesStrings.Localizable.modalLeaveShareDescription(file.name), boldText: file.name)
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
                    UIConstants.showSnackBar(message: error.localizedDescription)
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
        present(activityViewController, animated: true)
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
        MatomoUtils.trackFileAction(action: action, file: file, fromPhotoList: presentingParent is PhotoListViewController)
        handleAction(action, at: indexPath)
    }
}

// MARK: - Collection view drag delegate

extension FileActionsFloatingPanelViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard Self.sections[indexPath.section] == .header, file.capabilities.canMove && !sharedWithMe else {
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
