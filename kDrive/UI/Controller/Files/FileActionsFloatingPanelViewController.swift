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

final class FileActionsFloatingPanelViewController: UICollectionViewController {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var router: AppNavigable
    @LazyInjectService var downloadQueue: DownloadQueueable

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
    lazy var packId = DrivePackId(rawValue: driveFileManager.drive.pack.name)

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
                    heightDimension: .absolute(UIConstants.FileList.cellHeight)
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
        guard let activeScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let observerViewController = activeScene.windows.first?.rootViewController else {
            return
        }

        downloadAction = action
        setLoading(true, action: action, at: indexPath)
        downloadObserver?.cancel()
        downloadObserver = downloadQueue
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
            downloadQueue.addPublicShareToQueue(file: file,
                                                driveFileManager: driveFileManager,
                                                publicShareProxy: publicShareProxy,
                                                itemIdentifier: nil,
                                                onOperationCreated: nil, completion: nil)
        } else {
            downloadQueue.addToQueue(file: file,
                                     userId: accountManager.currentUserId, itemIdentifier: nil)
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
            cell.configure(
                with: action,
                file: file,
                showProgress: downloadAction == action,
                driveFileManager: driveFileManager,
                currentPackId: packId
            )
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
