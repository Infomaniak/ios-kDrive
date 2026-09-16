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

import DifferenceKit
import InfomaniakCore
import InfomaniakCoreCommonUI
import InfomaniakDI
import kDriveCore
import OSLog
import RealmSwift
import UIKit

typealias FileDisplayed = CornerCellContainer<File>

@MainActor
protocol UploadFolderResolving {
    func cachedFolder(_ file: ProxyFile) -> File?
    func loadFolder(_ file: ProxyFile) async throws
}

private struct UploadFolderResolver: UploadFolderResolving {
    let accountManager: AccountManageable
    let userId: Int

    func cachedFolder(_ file: ProxyFile) -> File? {
        accountManager.getDriveFileManager(for: file.driveId, userId: userId)?.getCachedFile(id: file.id)
    }

    func loadFolder(_ file: ProxyFile) async throws {
        guard let manager = accountManager.getDriveFileManager(for: file.driveId, userId: userId) else {
            throw DriveError.NoDriveError.noDriveFileManager
        }
        _ = try await manager.file(file)
    }
}

final class UploadQueueFoldersViewController: UITableViewController {
    private struct FolderIdentifier: Hashable {
        let driveId: Int
        let parentId: Int
    }

    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var driveInfosManager: DriveInfosManager
    @LazyInjectService private var uploadDataSource: UploadServiceDataSourceable
    @LazyInjectService private var matomo: MatomoUtils

    private var frozenUploadingFolders = [FileDisplayed]()
    private var notificationToken: NotificationToken?
    private var driveFileManager: DriveFileManager!
    private var uploadingFiles: Results<UploadFile>?
    private var requestedFolders = Set<FolderIdentifier>()
    private var folderLoadingTasks: [FolderIdentifier: Task<Void, Never>] = [:]
    private var folderResolver: UploadFolderResolving?

    private var userId: Int {
        return driveFileManager.drive.userId
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        tableView.register(cellView: UploadFolderTableViewCell.self)

        setUpObserver()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: [MatomoUtils.View.uploadQueue.displayName, "Folders"])
    }

    deinit {
        notificationToken?.invalidate()
        folderLoadingTasks.values.forEach { $0.cancel() }
    }

    private func setUpObserver() {
        guard driveFileManager != nil else { return }
        let driveIds = [driveFileManager.driveId] + driveInfosManager.getDrives(for: userId, sharedWithMe: true)
            .map(\.id)
        let uploadingFiles = uploadDataSource.getUploadingFiles(userId: userId, driveIds: driveIds)
            .distinct(by: [\.driveId, \.parentDirectoryId])
        observeUploads(uploadingFiles, folderResolver: UploadFolderResolver(accountManager: accountManager, userId: userId))
    }

    func observeUploads(_ uploadingFiles: Results<UploadFile>, folderResolver: UploadFolderResolving) {
        notificationToken?.invalidate()
        self.folderResolver = folderResolver
        self.uploadingFiles = uploadingFiles

        notificationToken = uploadingFiles.observe(keyPaths: UploadFile.observedProperties, on: .main) { [weak self] change in
            guard let self else {
                return
            }

            switch change {
            case .initial(let results):
                updateFolders(from: results)
            case .update(let results, _, _, _):
                updateFolders(from: results)
            case .error(let error):
                Logger.realmObservation.error("Realm observer error: \(error)")
            }
        }
    }

    private func updateFolders(from results: Results<UploadFile>) {
        let files = results.map { FolderIdentifier(driveId: $0.driveId, parentId: $0.parentDirectoryId) }
        let cachedFolders: [File] = files.compactMap { tuple in
            let parentId = tuple.parentId
            let driveId = tuple.driveId

            guard let folder = folderResolver?.cachedFolder(ProxyFile(driveId: driveId, id: parentId)) else {
                loadFolderIfNeeded(tuple)
                return nil
            }

            return folder
        }
        let folders = cachedFolders.enumerated().map { index, folder in
            return FileDisplayed(isFirstInList: index == 0,
                                 isLastInList: index == cachedFolders.count - 1,
                                 content: folder)
        }

        let changeSet = StagedChangeset(source: frozenUploadingFolders, target: folders)
        tableView.reload(using: changeSet,
                         with: UITableView.RowAnimation.automatic,
                         interrupt: { $0.changeCount > Endpoint.itemsPerPage },
                         setData: { self.frozenUploadingFolders = $0 })

        if results.isEmpty, navigationController?.topViewController === self {
            navigationController?.popViewController(animated: true)
        }
    }

    private func loadFolderIfNeeded(_ identifier: FolderIdentifier) {
        guard let folderResolver, requestedFolders.insert(identifier).inserted else { return }

        folderLoadingTasks[identifier] = Task { @MainActor [weak self] in
            defer { self?.folderLoadingTasks[identifier] = nil }
            do {
                try await folderResolver.loadFolder(ProxyFile(driveId: identifier.driveId, id: identifier.parentId))
                guard !Task.isCancelled, let self, let uploadingFiles = self.uploadingFiles else { return }
                // Use the current queue: uploads may have completed while the folder was loading.
                updateFolders(from: uploadingFiles)
            } catch {
                guard !Task.isCancelled else { return }
                let metadata = ["parentId": "\(identifier.parentId)", "driveId": "\(identifier.driveId)"]
                Log.fileList("Unable to load upload destination: \(error)", metadata: metadata, level: .error)
            }
        }
    }

    static func instantiate(driveFileManager: DriveFileManager) -> UploadQueueFoldersViewController {
        let viewController = Storyboard.files
            .instantiateViewController(withIdentifier: "UploadQueueFoldersViewController") as! UploadQueueFoldersViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return frozenUploadingFolders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UploadFolderTableViewCell.self, for: indexPath)

        let folderDisplayed = frozenUploadingFolders[indexPath.row]
        cell.configure(with: folderDisplayed.content, drive: driveFileManager.drive)

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let uploadViewController = UploadQueueViewController.instantiate()
        uploadViewController.currentDirectory = frozenUploadingFolders[indexPath.row].content
        navigationController?.pushViewController(uploadViewController, animated: true)
    }
}
