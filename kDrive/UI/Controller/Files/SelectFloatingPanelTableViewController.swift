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

class SelectFloatingPanelTableViewController: FileQuickActionsFloatingPanelViewController {

    var files: [File]!
    var changedFiles: [File]? = []
    var downloadInProgress = false

    var filesAvailableOffline: Bool {
        return files.allSatisfy(\.isAvailableOffline)
    }

    var filesAreFavorite: Bool {
        return files.allSatisfy(\.isFavorite)
    }

    lazy var actions: [FloatingPanelAction] = {
        if sharedWithMe {
            return FloatingPanelAction.multipleSelectionSharedWithMeActions
        } else {
            return FloatingPanelAction.multipleSelectionActions
        }
    }()

    var reloadAction: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorColor = .clear
        tableView.alwaysBounceVertical = false
        tableView.register(cellView: FloatingPanelTableViewCell.self)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FloatingPanelTableViewCell.self, for: indexPath)

        let action = actions[indexPath.row]
        cell.titleLabel.text = action.name
        cell.accessoryImageView.image = action.image
        cell.accessoryImageView.tintColor = action.tintColor

        if action == .favorite && filesAreFavorite {
            cell.titleLabel.text = action.reverseName
            cell.accessoryImageView.tintColor = KDriveAsset.favoriteColor.color
        } else if action == .offline {
            cell.offlineSwitch.isHidden = false
            cell.accessoryImageView.image = filesAvailableOffline ? KDriveAsset.check.image : action.image
            cell.accessoryImageView.tintColor = filesAvailableOffline ? KDriveAsset.greenColor.color : action.tintColor
            cell.offlineSwitch.isOn = filesAvailableOffline
            cell.setProgress(downloadInProgress ? -1 : nil)
            // Disable cell if all selected items are folders
            cell.setEnabled(!files.allSatisfy(\.isDirectory))
        } else if action == .download {
            cell.setProgress(downloadInProgress ? -1 : nil)
        }
        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let action = actions[indexPath.row]
        var success = true
        var addAction = true
        let group = DispatchGroup()

        switch action {
        case .offline:
            let isAvailableOffline = filesAvailableOffline
            addAction = !isAvailableOffline
            if !isAvailableOffline {
                downloadInProgress = true
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
            }
            for file in files where !file.isDirectory {
                group.enter()
                driveFileManager.setFileAvailableOffline(file: file, available: !isAvailableOffline) { error in
                    if error != nil {
                        success = false
                    }
                    if let file = self.driveFileManager.getCachedFile(id: file.id) {
                        self.changedFiles?.append(file)
                    }
                    group.leave()
                }
            }
        case .favorite:
            let isFavorite = filesAreFavorite
            addAction = !isFavorite
            for file in files where (file.rights?.canFavorite.value ?? false) {
                group.enter()
                driveFileManager.setFavoriteFile(file: file, favorite: !isFavorite) { error in
                    if error != nil {
                        success = false
                    }
                    if let file = self.driveFileManager.getCachedFile(id: file.id) {
                        self.changedFiles?.append(file)
                    }
                    group.leave()
                }
            }
        case .download:
            for file in files {
                if file.isDownloaded {
                    saveLocalFile(file: file)
                } else {
                    downloadInProgress = true
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                    group.enter()
                    DownloadQueue.instance.observeFileDownloaded(self, fileId: file.id) { [unowned self] _, error in
                        if error != nil {
                            success = false
                        }
                        DispatchQueue.main.async {
                            saveLocalFile(file: file)
                        }
                        group.leave()
                    }
                    DownloadQueue.instance.addToQueue(file: file)
                }
            }
        default:
            break
        }

        group.notify(queue: DispatchQueue.main) {
            if success {
                if action == .offline && addAction {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileListAddOfflineConfirmationSnackbar(self.files.count))
                } else if action == .favorite && addAction {
                    UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileListAddFavorisConfirmationSnackbar(self.files.count))
                }
            } else {
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
            }
            self.files = self.changedFiles
            self.downloadInProgress = false
            self.tableView.reloadRows(at: [indexPath], with: .fade)
            self.dismiss(animated: true)
            self.reloadAction?()
            self.changedFiles = []
        }
    }
}
