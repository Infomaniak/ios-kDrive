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
import RealmSwift
import UIKit

final class UploadQueueViewController: UIViewController {
    @LazyInjectService private var driveUploadManager: DriveUploadManager

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var retryButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!

    @LazyInjectService var accountManager: AccountManageable
    @LazyInjectService var uploadQueue: UploadQueue

    var currentDirectory: File!
    private var uploadingFiles = AnyRealmCollection(List<UploadFile>())
    private var notificationToken: NotificationToken?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        tableView.register(cellView: UploadTableViewCell.self)

        retryButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonRetry
        cancelButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonCancel

        setUpObserver()

        ReachabilityListener.instance.observeNetworkChange(self) { [weak self] _ in
            Task { @MainActor in
                self?.tableView.reloadData()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: [MatomoUtils.Views.uploadQueue.displayName, "Main"])
    }

    deinit {
        notificationToken?.invalidate()
    }

    func setUpObserver() {
        guard let currentDirectory, !currentDirectory.isInvalidated else {
            return
        }

        let realm = driveUploadManager.getRealm()
        notificationToken?.invalidate()
        notificationToken = uploadQueue.getUploadingFiles(withParent: currentDirectory.id,
                                                          userId: accountManager.currentUserId,
                                                          driveId: currentDirectory.driveId,
                                                          using: realm)
            .observe(keyPaths: UploadFile.observedProperties, on: .main) { [weak self] change in
                guard let self else {
                    return
                }

                switch change {
                case .initial(let results):
                    uploadingFiles = AnyRealmCollection(results)
                    tableView.reloadData()
                    if results.isEmpty {
                        navigationController?.popViewController(animated: true)
                    }
                case .update(let results, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                    uploadingFiles = AnyRealmCollection(results)

                    guard !results.isEmpty else {
                        navigationController?.popViewController(animated: true)
                        return
                    }

                    tableView.performBatchUpdates {
                        // Always apply updates in the following order: deletions, insertions, then modifications.
                        // Handling insertions before deletions may result in unexpected behavior.
                        self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                        self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                        self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                    }
                    // Update cell corners
                    tableView.reloadCorners(insertions: insertions, deletions: deletions, count: results.count)
                case .error(let error):
                    DDLogError("Realm observer error: \(error)")
                }
            }
    }

    @IBAction func cancelButtonPressed(_ sender: UIBarButtonItem) {
        uploadQueue.cancelAllOperations(withParent: currentDirectory.id,
                                        userId: accountManager.currentUserId,
                                        driveId: currentDirectory.driveId)
    }

    @IBAction func retryButtonPressed(_ sender: UIBarButtonItem) {
        uploadQueue.retryAllOperations(withParent: currentDirectory.id,
                                       userId: accountManager.currentUserId,
                                       driveId: currentDirectory.driveId)
    }

    class func instantiate() -> UploadQueueViewController {
        return Storyboard.files
            .instantiateViewController(withIdentifier: "UploadQueueViewController") as! UploadQueueViewController
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

        guard let driveFileManager = accountManager.getDriveFileManager(for: driveId, userId: accountManager.currentUserId),
              let directory = driveFileManager.getCachedFile(id: directoryId) else {
            // Handle error?
            return
        }
        currentDirectory = directory
        setUpObserver()
    }
}

// MARK: - Table view data source

extension UploadQueueViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploadingFiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: UploadTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: indexPath.row == 0,
                                       isLast: indexPath.row == self.tableView(
                                           tableView,
                                           numberOfRowsInSection: indexPath.section
                                       ) - 1)

        /// Make sure the file is valid
        let file = uploadingFiles[indexPath.row]
        if !file.isInvalidated {
            let progress: CGFloat? = (file.progress != nil) ? CGFloat(file.progress!) : nil
            cell.configureWith(uploadFile: file, progress: progress)
        }

        cell.selectionStyle = .none
        return cell
    }
}
