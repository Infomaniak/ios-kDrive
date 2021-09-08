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

import kDriveCore
import UIKit

class UploadQueueFoldersViewController: UITableViewController {
    var driveFileManager: DriveFileManager!

    private let realm = DriveFileManager.constants.uploadsRealm

    private var folders: [File] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: UploadFolderTableViewCell.self)

        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reload()
    }

    private func reload() {
        guard driveFileManager != nil else { return }
        // First, get all uploading files
        let uploadingFiles = UploadQueue.instance.getUploadingFiles(userId: driveFileManager.drive.userId, driveId: driveFileManager.drive.id, using: realm)
        // Then, get parent ids and remove duplicates
        var seen: Set<Int> = []
        let parentIds = Array(uploadingFiles.filter { seen.insert($0.parentDirectoryId).inserted }.map(\.parentDirectoryId))
        // (Pop view controller if nothing to show)
        if parentIds.isEmpty {
            navigationController?.popViewController(animated: true)
            return
        }
        // Finally, get the folders
        folders = parentIds.compactMap { driveFileManager.getCachedFile(id: $0) }
        tableView.reloadData()
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
