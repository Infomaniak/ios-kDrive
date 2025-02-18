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
import DifferenceKit
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import RealmSwift
import UIKit

typealias FileDisplayed = CornerCellContainer<File>

final class UploadQueueFoldersViewController: UITableViewController {
    @LazyInjectService private var accountManager: AccountManageable
    @LazyInjectService private var driveInfosManager: DriveInfosManager
    @LazyInjectService private var uploadQueue: UploadQueue

    private var frozenUploadingFolders = [FileDisplayed]()
    private var notificationToken: NotificationToken?
    private var driveFileManager: DriveFileManager!

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
        MatomoUtils.track(view: [MatomoUtils.Views.uploadQueue.displayName, "Folders"])
    }

    deinit {
        notificationToken?.invalidate()
    }

    private func setUpObserver() {
        guard driveFileManager != nil else { return }
        let driveIds = [driveFileManager.driveId] + driveInfosManager.getDrives(for: userId, sharedWithMe: true)
            .map(\.id)
        let uploadingFiles = uploadQueue.getUploadingFiles(userId: userId, driveIds: driveIds)
            .distinct(by: [\.parentDirectoryId])

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
                DDLogError("Realm observer error: \(error)")
            }
        }
    }

    private func updateFolders(from results: Results<UploadFile>) {
        let files = results.map { (driveId: $0.driveId, parentId: $0.parentDirectoryId) }
        let filesCount = files.count
        let folders: [FileDisplayed] = files.enumerated().compactMap { index, tuple in
            let parentId = tuple.parentId
            let driveId = tuple.driveId

            guard let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: userId) else {
                let metadata = ["parentId": "\(parentId)", "driveId": "\(driveId)", "userId": "\(userId)"]
                Log.fileList("Unable to fetch a driveFileManager to display a file", metadata: metadata, level: .error)
                return nil
            }

            // FIXME: orphan files not displayed
            guard let folder = driveFileManager.getCachedFile(id: parentId) else {
                let metadata = ["parentId": "\(parentId)", "driveId": "\(driveId)"]
                Log.fileList("Unable to fetch parent folder to display file", metadata: metadata, level: .error)
                return nil
            }

            return FileDisplayed(isFirstInList: index == 0,
                                 isLastInList: index == filesCount - 1,
                                 content: folder)
        }

        let changeSet = StagedChangeset(source: frozenUploadingFolders, target: folders)
        tableView.reload(using: changeSet,
                         with: UITableView.RowAnimation.automatic,
                         interrupt: { $0.changeCount > Endpoint.itemsPerPage },
                         setData: { self.frozenUploadingFolders = $0 })

        if folders.isEmpty {
            navigationController?.popViewController(animated: true)
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
        cell.initWithPositionAndShadow(isFirst: folderDisplayed.isFirstInList,
                                       isLast: folderDisplayed.isLastInList)
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
