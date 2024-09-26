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
import InfomaniakDI
import kDriveCore
import kDriveResources
import LinkPresentation
import UIKit

public class FloatingPanelAction: Equatable {
    let id: Int
    let name: String
    var reverseName: String?
    let image: UIImage
    var tintColor: UIColor = KDriveResourcesAsset.iconColor.color
    var isLoading = false
    var isEnabled = true

    init(
        id: Int,
        name: String,
        reverseName: String? = nil,
        image: UIImage,
        tintColor: UIColor = KDriveResourcesAsset.iconColor.color
    ) {
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

    static let openWith = FloatingPanelAction(
        id: 0,
        name: KDriveResourcesStrings.Localizable.buttonOpenWith,
        image: KDriveResourcesAsset.openWith.image
    )
    static let edit = FloatingPanelAction(
        id: 1,
        name: KDriveResourcesStrings.Localizable.buttonEdit,
        image: KDriveResourcesAsset.editDocument.image
    )
    static let manageCategories = FloatingPanelAction(
        id: 2,
        name: KDriveResourcesStrings.Localizable.manageCategoriesTitle,
        image: KDriveResourcesAsset.categories.image
    )
    static let favorite = FloatingPanelAction(
        id: 3,
        name: KDriveResourcesStrings.Localizable.buttonAddFavorites,
        reverseName: KDriveResourcesStrings.Localizable.buttonRemoveFavorites,
        image: KDriveResourcesAsset.favorite.image
    )
    static let convertToDropbox = FloatingPanelAction(
        id: 4,
        name: KDriveResourcesStrings.Localizable.buttonConvertToDropBox,
        image: KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate)
    )
    static let folderColor = FloatingPanelAction(
        id: 5,
        name: KDriveResourcesStrings.Localizable.buttonChangeFolderColor,
        image: KDriveResourcesAsset.colorBucket.image
    )
    static let manageDropbox = FloatingPanelAction(
        id: 6,
        name: KDriveResourcesStrings.Localizable.buttonManageDropBox,
        image: KDriveResourcesAsset.folderDropBox.image.withRenderingMode(.alwaysTemplate)
    )
    static let seeFolder = FloatingPanelAction(
        id: 7,
        name: KDriveResourcesStrings.Localizable.buttonSeeFolder,
        image: KDriveResourcesAsset.folderFilled.image.withRenderingMode(.alwaysTemplate)
    )
    static let offline = FloatingPanelAction(
        id: 8,
        name: KDriveResourcesStrings.Localizable.buttonAvailableOffline,
        image: KDriveResourcesAsset.availableOffline.image
    )
    static let download = FloatingPanelAction(
        id: 9,
        name: KDriveResourcesStrings.Localizable.buttonDownload,
        image: KDriveResourcesAsset.download.image
    )
    static let move = FloatingPanelAction(
        id: 10,
        name: KDriveResourcesStrings.Localizable.buttonMoveTo,
        image: KDriveResourcesAsset.folderSelect.image
    )
    static let duplicate = FloatingPanelAction(
        id: 11,
        name: KDriveResourcesStrings.Localizable.buttonDuplicate,
        image: KDriveResourcesAsset.duplicate.image
    )
    static let rename = FloatingPanelAction(
        id: 12,
        name: KDriveResourcesStrings.Localizable.buttonRename,
        image: KDriveResourcesAsset.edit.image
    )
    static let delete = FloatingPanelAction(
        id: 13,
        name: KDriveResourcesStrings.Localizable.modalMoveTrashTitle,
        image: KDriveResourcesAsset.delete.image,
        tintColor: KDriveResourcesAsset.binColor.color
    )
    static let leaveShare = FloatingPanelAction(
        id: 14,
        name: KDriveResourcesStrings.Localizable.buttonLeaveShare,
        image: KDriveResourcesAsset.linkBroken.image
    )
    static let cancelImport = FloatingPanelAction(
        id: 15,
        name: KDriveResourcesStrings.Localizable.buttonCancelImport,
        image: KDriveResourcesAsset.remove.image,
        tintColor: KDriveCoreAsset.binColor.color
    )

    static var listActions: [FloatingPanelAction] {
        return [
            openWith,
            edit,
            manageCategories,
            favorite,
            seeFolder,
            offline,
            download,
            move,
            duplicate,
            rename,
            leaveShare,
            delete
        ].map { $0.reset() }
    }

    static var folderListActions: [FloatingPanelAction] {
        return [
            manageCategories,
            favorite,
            folderColor,
            convertToDropbox,
            manageDropbox,
            seeFolder,
            download,
            move,
            duplicate,
            rename,
            leaveShare,
            delete,
            cancelImport
        ].map { $0.reset() }
    }

    static let informations = FloatingPanelAction(
        id: 16,
        name: KDriveResourcesStrings.Localizable.fileDetailsInfosTitle,
        image: KDriveResourcesAsset.info.image
    )
    static let add = FloatingPanelAction(
        id: 17,
        name: KDriveResourcesStrings.Localizable.buttonAdd,
        image: KDriveResourcesAsset.add.image
    )
    static let sendCopy = FloatingPanelAction(
        id: 18,
        name: KDriveResourcesStrings.Localizable.buttonSendCopy,
        image: KDriveResourcesAsset.exportIos.image
    )
    static let shareAndRights = FloatingPanelAction(
        id: 19,
        name: KDriveResourcesStrings.Localizable.buttonFileRights,
        image: KDriveResourcesAsset.share.image
    )
    static let shareLink = FloatingPanelAction(id: 20,
                                               name: KDriveResourcesStrings.Localizable.buttonCreatePublicLink,
                                               reverseName: KDriveResourcesStrings.Localizable.buttonSharePublicLink,
                                               image: KDriveResourcesAsset.link.image)

    static var quickActions: [FloatingPanelAction] {
        return [informations, sendCopy, shareAndRights, shareLink].map { $0.reset() }
    }

    static var folderQuickActions: [FloatingPanelAction] {
        return [informations, add, shareAndRights, shareLink].map { $0.reset() }
    }

    static var publicShareActions: [FloatingPanelAction] {
        return [openWith, sendCopy, download].map { $0.reset() }
    }

    static var publicShareFolderActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var multipleSelectionActions: [FloatingPanelAction] {
        return [manageCategories, favorite, offline, download, move, duplicate].map { $0.reset() }
    }

    static var multipleSelectionActionsOnlyFolders: [FloatingPanelAction] {
        return [manageCategories, favorite, folderColor, offline, download, move, duplicate].map { $0.reset() }
    }

    static var multipleSelectionSharedWithMeActions: [FloatingPanelAction] {
        return [download].map { $0.reset() }
    }

    static var multipleSelectionPhotosListActions: [FloatingPanelAction] {
        return [manageCategories, favorite, download, move, duplicate, .offline].map { $0.reset() }
    }

    static var multipleSelectionBulkActions: [FloatingPanelAction] {
        return [offline, download, move, duplicate].map { $0.reset() }
    }

    static var selectAllActions: [FloatingPanelAction] {
        return [.offline, download, move, duplicate].map { $0.reset() }
    }

    public static func == (lhs: FloatingPanelAction, rhs: FloatingPanelAction) -> Bool {
        return lhs.id == rhs.id
    }
}

final class FileActionsFloatingPanelViewController: UICollectionViewController {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable

    var driveFileManager: DriveFileManager!
    var file: File!
    var normalFolderHierarchy = true
    var presentationOrigin = PresentationOrigin.fileList
    weak var presentingParent: UIViewController?
    var matomoCategory: MatomoUtils.EventCategory {
        if presentingParent is PhotoListViewController {
            return .picturesFileAction
        }
        return .fileListFileAction
    }

    var sharedWithMe: Bool {
        return file.visibility == .isInSharedSpace
    }

    enum Section: CaseIterable {
        case header, quickActions, actions
    }

    static var sections: [Section] {
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
            Task { @MainActor in
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
                let message = "Got a file that doesn't exist in Realm in FileQuickActionsFloatingPanelViewController!"
                SentryDebug.capture(message: message)
            }
        }

        if file == nil || file != newFile {
            file = newFile
            fileObserver?.cancel()
            fileObserver = driveFileManager.observeFileUpdated(self, fileId: file.id) { [weak self] _ in
                Task { @MainActor in
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
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(UIConstants.fileListCellHeight)
                )
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

    func setLoading(_ isLoading: Bool, action: FloatingPanelAction, at indexPath: IndexPath) {
        action.isLoading = isLoading
        Task { @MainActor [weak self] in
            self?.collectionView.reloadItems(at: [indexPath])
        }
    }

    func presentShareSheet(from indexPath: IndexPath) {
        let activityViewController = UIActivityViewController(activityItems: [file.localUrl], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = collectionView
            .cellForItem(at: indexPath) ?? collectionView
        present(activityViewController, animated: true)
    }

    func downloadFile(action: FloatingPanelAction,
                      indexPath: IndexPath,
                      completion: @escaping () -> Void) {
        guard let observerViewController = UIApplication.shared.windows.first?.rootViewController else { return }
        downloadAction = action
        setLoading(true, action: action, at: indexPath)
        downloadObserver?.cancel()
        downloadObserver = DownloadQueue.instance
            .observeFileDownloaded(observerViewController, fileId: file.id) { [weak self] _, error in
                self?.downloadAction = nil
                self?.setLoading(true, action: action, at: indexPath)
                Task { @MainActor in
                    if error == nil {
                        completion()
                    } else {
                        UIConstants.showSnackBarIfNeeded(error: DriveError.downloadFailed)
                    }
                }
            }

        if let publicShareProxy = driveFileManager.publicShareProxy {
            DownloadQueue.instance.addPublicShareToQueue(file: file,
                                                         driveFileManager: driveFileManager,
                                                         publicShareProxy: publicShareProxy)
        } else {
            DownloadQueue.instance.addToQueue(file: file,
                                              userId: accountManager.currentUserId)
        }
    }

    func copyShareLinkToPasteboard(from indexPath: IndexPath, link: String) {
        UIConstants.presentLinkPreviewForFile(
            file,
            link: link,
            from: self,
            sourceView: collectionView.cellForItem(at: indexPath) ?? collectionView
        )
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

        let eventCategory: MatomoUtils.EventCategory
        if presentingParent is PhotoListViewController {
            eventCategory = .picturesFileAction
        } else if driveFileManager.isPublicShare {
            eventCategory = .publicShareAction
        } else {
            eventCategory = .fileListFileAction
        }

        MatomoUtils.trackFileAction(action: action, file: file, category: eventCategory)
        handleAction(action, at: indexPath)
    }
}

// MARK: - Collection view drag delegate

extension FileActionsFloatingPanelViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
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
    func documentInteractionController(
        _ controller: UIDocumentInteractionController,
        willBeginSendingToApplication application: String?
    ) {
        // Dismiss interaction controller when the user taps an app
        controller.dismissMenu(animated: true)
    }
}
