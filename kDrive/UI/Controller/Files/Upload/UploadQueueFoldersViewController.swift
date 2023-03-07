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
import InfomaniakDI
import kDriveCore
import RealmSwift
import UIKit

class UploadQueueFoldersViewController: UITableViewController {
    var driveFileManager: DriveFileManager!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadQueue: UploadQueue

    private let realm = DriveFileManager.constants.uploadsRealm

    private var userId: Int {
        return driveFileManager.drive.userId
    }

    private var folders: [File] = []
    private var notificationToken: NotificationToken?

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
        // Get the drives (current + shared with me)
        let driveIds = [driveFileManager.drive.id] + DriveInfosManager.instance.getDrives(for: userId, sharedWithMe: true).map(\.id)
        // Observe uploading files
        notificationToken = uploadQueue.getUploadingFiles(userId: userId, driveIds: driveIds, using: realm)
            .distinct(by: [\.parentDirectoryId])
            .observe(keyPaths: UploadFile.observedProperties, on: .main) { [weak self] change in
                guard let self else {
                    return
                }

                switch change {
                case .initial(let results):
                    self.updateFolders(from: results)
                    self.tableView.reloadData()
                    if results.isEmpty {
                        self.navigationController?.popViewController(animated: true)
                    }
                case .update(let results, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                    guard !results.isEmpty else {
                        self.navigationController?.popViewController(animated: true)
                        return
                    }

                    // No animation on updating the same lines
                    let rowAnimation: UITableView.RowAnimation
                    if deletions == insertions, modifications.isEmpty {
                        rowAnimation = .none
                    } else {
                        rowAnimation = .automatic
                    }

                    self.tableView.performBatchUpdates {
                        self.updateFolders(from: results)
                        // Always apply updates in the following order: deletions, insertions, then modifications.
                        // Handling insertions before deletions may result in unexpected behavior.
                        self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: rowAnimation)
                        self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: rowAnimation)
                        self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: rowAnimation)
                    }
                case .error(let error):
                    DDLogError("Realm observer error: \(error)")
                }
            }
    }

    private func updateFolders(from results: Results<UploadFile>) {
        let files = results.map { (driveId: $0.driveId, parentId: $0.parentDirectoryId) }
        folders = files.compactMap { accountManager.getDriveFileManager(for: $0.driveId, userId: userId)?.getCachedFile(id: $0.parentId) }
        // (Pop view controller if nothing to show)
        if folders.isEmpty {
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }

    static func instantiate(driveFileManager: DriveFileManager) -> UploadQueueFoldersViewController {
        let viewController = Storyboard.files.instantiateViewController(withIdentifier: "UploadQueueFoldersViewController") as! UploadQueueFoldersViewController
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UploadFolderTableViewCell.self, for: indexPath)

        let folder = folders[indexPath.row]
        cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == folders.count - 1)
        cell.configure(with: folder, drive: driveFileManager.drive)

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let uploadViewController = UploadQueueViewController.instantiate()
        uploadViewController.currentDirectory = folders[indexPath.row]
        navigationController?.pushViewController(uploadViewController, animated: true)
    }
}
