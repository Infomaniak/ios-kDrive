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
import UIKit

final class MultipleSelectionFloatingPanelViewController: UICollectionViewController {
    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var appNavigable: AppNavigable

    let driveFileManager: DriveFileManager
    var files: [File]
    let allItemsSelected: Bool
    let exceptFileIds: [Int]?
    let currentDirectory: File
    let reloadAction: (() -> Void)?

    var changedFiles: [File]? = []
    var downloadInProgress = false
    var downloadedArchiveUrl: URL?
    var success = true
    var addAction = true
    var currentArchiveId: String?
    var downloadError: DriveError?

    weak var presentingParent: UIViewController?

    var sharedWithMe: Bool {
        return currentDirectory.visibility == .isInSharedSpace || currentDirectory.visibility == .isSharedSpace
    }

    var actions: [FloatingPanelAction] = []

    init(
        driveFileManager: DriveFileManager,
        currentDirectory: File,
        files: [File],
        allItemsSelected: Bool,
        exceptFileIds: [Int]?,
        reloadAction: (() -> Void)?,
        presentingParent: UIViewController?
    ) {
        self.driveFileManager = driveFileManager
        self.currentDirectory = currentDirectory
        self.files = files
        self.allItemsSelected = allItemsSelected
        self.exceptFileIds = exceptFileIds
        self.reloadAction = reloadAction
        self.presentingParent = presentingParent
        super.init(collectionViewLayout: MultipleSelectionFloatingPanelViewController.createLayout())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(cellView: FloatingPanelActionCollectionViewCell.self)
        collectionView.alwaysBounceVertical = false
        setupContent()
    }

    func setupContent() {
        guard actions.isEmpty else { return }

        if sharedWithMe {
            actions = FloatingPanelAction.multipleSelectionSharedWithMeActions
        } else if allItemsSelected {
            actions = FloatingPanelAction.selectAllActions
        } else if files.count > Constants.bulkActionThreshold || allItemsSelected {
            actions = FloatingPanelAction.multipleSelectionBulkActions
            if files.contains(where: { $0.parentId != files.first?.parentId }) {
                actions.removeAll { $0 == .download }
            }
        } else if presentingParent is PhotoListViewController {
            actions = FloatingPanelAction.multipleSelectionPhotosListActions
        } else {
            if files.contains(where: { !$0.isDirectory }) {
                actions = FloatingPanelAction.multipleSelectionActions
            } else {
                actions = FloatingPanelAction.multipleSelectionActionsOnlyFolders
            }
        }
    }

    // MARK: - Private methods

    @MainActor
    func copy(files: [File], to selectedDirectory: File) async throws {
        if files.count > Constants.bulkActionThreshold || allItemsSelected {
            // addAction = false // Prevents the snackbar to be displayed
            let action: BulkAction
            if allItemsSelected {
                action = BulkAction(
                    action: .copy,
                    parentId: currentDirectory.id,
                    exceptFileIds: exceptFileIds,
                    destinationDirectoryId: selectedDirectory.id
                )
            } else {
                action = BulkAction(action: .copy, fileIds: files.map(\.id), destinationDirectoryId: selectedDirectory.id)
            }
            let tabBarController = presentingViewController as? MainTabViewController
            let navigationController = tabBarController?.selectedViewController as? UINavigationController
            await (navigationController?.topViewController as? FileListViewController)?.viewModel.multipleSelectionViewModel?
                .performAndObserve(bulkAction: action)
        } else {
            // MainActor should ensure that this call is safe as file was created on the main thread ?
            let proxyFiles = files.map { $0.proxify() }
            let proxySelectedDirectory = selectedDirectory.proxify()
            try await withThrowingTaskGroup(of: Void.self) { group in
                for proxyFile in proxyFiles {
                    group.addTask {
                        _ = try await self.driveFileManager.apiFetcher.copy(file: proxyFile, to: proxySelectedDirectory)
                    }
                }
                try await group.waitForAll()
            }
        }
    }

    // TODO:  make it work
    func downloadPublicShareArchivedFiles(downloadCellPath: IndexPath,
                                          publicShareProxy: PublicShareProxy,
                                          completion: @escaping (Result<URL, DriveError>) -> Void) {
        Task { [proxyFiles = files.map { $0.proxify() }, currentProxyDirectory = currentDirectory.proxify()] in
            do {
                let archiveBody: ArchiveBody
                if allItemsSelected {
                    archiveBody = .init(parentId: currentProxyDirectory.id, exceptFileIds: exceptFileIds)
                } else {
                    archiveBody = .init(files: proxyFiles)
                }

                let response = try await PublicShareApiFetcher().buildPublicShareArchive(
                    driveId: publicShareProxy.driveId,
                    linkUuid: publicShareProxy.shareLinkUid,
                    body: archiveBody
                )
                currentArchiveId = response.uuid
                guard let rootViewController = view.window?.rootViewController else { return }
                DownloadQueue.instance
                    .observeArchiveDownloaded(rootViewController, archiveId: response.uuid) { _, archiveUrl, error in
                        if let archiveUrl {
                            completion(.success(archiveUrl))
                        } else {
                            completion(.failure(error ?? .unknownError))
                        }
                    }
                DownloadQueue.instance.addPublicShareArchiveToQueue(archiveId: response.uuid,
                                                                    driveFileManager: driveFileManager,
                                                                    publicShareProxy: publicShareProxy)

                self.collectionView.reloadItems(at: [downloadCellPath])
            } catch {
                completion(.failure(error as? DriveError ?? .unknownError))
            }
        }
    }

    func downloadArchivedFiles(downloadCellPath: IndexPath,
                               completion: @escaping (Result<URL, DriveError>) -> Void) {
        Task { [proxyFiles = files.map { $0.proxify() }, currentProxyDirectory = currentDirectory.proxify()] in
            do {
                let archiveBody: ArchiveBody
                if allItemsSelected {
                    archiveBody = .init(parentId: currentProxyDirectory.id, exceptFileIds: exceptFileIds)
                } else {
                    archiveBody = .init(files: proxyFiles)
                }
                let response = try await self.driveFileManager.apiFetcher.buildArchive(
                    drive: driveFileManager.drive,
                    body: archiveBody
                )
                currentArchiveId = response.uuid
                guard let rootViewController = view.window?.rootViewController else { return }
                DownloadQueue.instance
                    .observeArchiveDownloaded(rootViewController, archiveId: response.uuid) { _, archiveUrl, error in
                        if let archiveUrl {
                            completion(.success(archiveUrl))
                        } else {
                            completion(.failure(error ?? .unknownError))
                        }
                    }

                if let publicShareProxy = self.driveFileManager.publicShareProxy {
                    DownloadQueue.instance.addPublicShareArchiveToQueue(archiveId: response.uuid,
                                                                        driveFileManager: driveFileManager,
                                                                        publicShareProxy: publicShareProxy)
                } else {
                    DownloadQueue.instance.addToQueue(archiveId: response.uuid,
                                                      driveId: self.driveFileManager.drive.id,
                                                      userId: accountManager.currentUserId)
                }

                self.collectionView.reloadItems(at: [downloadCellPath])
            } catch {
                completion(.failure(error as? DriveError ?? .unknownError))
            }
        }
    }

    private static func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(53))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            return NSCollectionLayoutSection(group: group)
        }
    }

    func favorite(file: File) async {
        if let file = driveFileManager.getCachedFile(id: file.id) {
            await MainActor.run {
                self.changedFiles?.append(file)
            }
        }
    }

    // MARK: - Collection view

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(type: FloatingPanelActionCollectionViewCell.self, for: indexPath)
        let action = actions[indexPath.item]
        cell.configure(with: action, files: files, showProgress: downloadInProgress, archiveId: currentArchiveId)
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = actions[indexPath.item]
        handleAction(action, at: indexPath)

        let eventCategory: MatomoUtils.EventCategory
        if presentingParent is PhotoListViewController {
            eventCategory = .picturesFileAction
        } else if driveFileManager.isPublicShare {
            eventCategory = .publicShareAction
        } else {
            eventCategory = .fileListFileAction
        }

        MatomoUtils.trackBuklAction(action: action, files: files, category: eventCategory)
    }
}
