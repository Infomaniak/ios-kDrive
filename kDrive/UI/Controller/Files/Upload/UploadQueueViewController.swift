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

import UIKit
import kDriveCore
import RealmSwift
import DifferenceKit

class UploadQueueViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var retryButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!

    var currentDirectory: File!
    private var uploadingFiles = [UploadFile]()
    private var progressForFileId = [String: CGFloat]()

    private let realm = DriveFileManager.constants.uploadsRealm

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: UploadTableViewCell.self)

        retryButton.accessibilityLabel = KDriveStrings.Localizable.buttonRetry
        cancelButton.accessibilityLabel = KDriveStrings.Localizable.buttonCancel

        reloadData(reloadTableView: false)
        UploadQueue.instance.observeFileUploaded(self) { _, _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isViewLoaded {
                    self.reloadData()
                }
            }
        }
        UploadQueue.instance.observeFileUploadProgress(self) { fileId, progress in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.progressForFileId[fileId] = CGFloat(progress)
                for cell in strongSelf.tableView.visibleCells {
                    (cell as? UploadTableViewCell)?.updateProgress(fileId: fileId, progress: CGFloat(progress))
                }
            }
        }

        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] _ in
            self.tableView.reloadData()
        }
    }

    func reloadData(reloadTableView: Bool = true) {
        let newUploadingFiles = Array(UploadQueue.instance.getUploadingFiles(withParent: currentDirectory.id, using: realm).freeze())
        newUploadingFiles.first?.isFirstInCollection = true
        newUploadingFiles.last?.isLastInCollection = true

        if reloadTableView {
            let changeSet = StagedChangeset(source: uploadingFiles, target: newUploadingFiles)
            tableView.reload(using: changeSet, with: .automatic) { newUploadingFiles in
                uploadingFiles = newUploadingFiles
            }
        } else {
            uploadingFiles = newUploadingFiles
        }

        if newUploadingFiles.isEmpty {
            navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        UploadQueue.instance.cancelAllOperations(withParent: currentDirectory.id)
        reloadData()
    }

    @IBAction func retryButtonPressed(_ sender: UIBarButtonItem) {
        UploadQueue.instance.retryAllOperations(withParent: currentDirectory.id)
        reloadData()
    }

    class func instantiate() -> UploadQueueViewController {
        return Storyboard.files.instantiateViewController(withIdentifier: "UploadQueueViewController") as! UploadQueueViewController
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(currentDirectory.driveId, forKey: "DriveID")
        coder.encode(currentDirectory.id, forKey: "DirectoryID")
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveID")
        let directoryId = coder.decodeInteger(forKey: "DirectoryID")

        guard let drive = DriveInfosManager.instance.getDrive(id: driveId, userId: AccountManager.instance.currentUserId),
            let driveFileManager = AccountManager.instance.getDriveFileManager(for: drive),
            let directory = driveFileManager.getCachedFile(id: directoryId) else {
            // Handle error?
            return
        }
        currentDirectory = directory
        reloadData(reloadTableView: true)
    }

}

// MARK: Table view data source

extension UploadQueueViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploadingFiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UploadTableViewCell.self, for: indexPath)
        let file = uploadingFiles[indexPath.row]
        cell.initWithPositionAndShadow(isFirst: file.isFirstInCollection, isLast: file.isLastInCollection)
        cell.configureWith(uploadFile: file, progress: progressForFileId[file.id])
        return cell
    }

}
