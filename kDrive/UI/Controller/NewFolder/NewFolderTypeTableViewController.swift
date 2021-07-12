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

import InfomaniakCore
import kDriveCore
import UIKit

class NewFolderTypeTableViewController: UITableViewController {
    var driveFileManager: DriveFileManager!
    var currentDirectory: File!

    private var content: [FolderType] = [.folder, .commonFolder, .dropbox]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: FolderTypeTableViewCell.self)
        tableView.separatorColor = .clear

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeButtonPressed))
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.largeTitleDisplayMode = .always

        title = KDriveStrings.Localizable.newFolderTitle

        setupFolderType()
    }

    func setupFolderType() {
        if driveFileManager.drive.pack == .solo || driveFileManager.drive.pack == .free {
            content.removeAll { $0 == .commonFolder }
        }
        if currentDirectory.visibility == .isTeamSpace {
            content.removeAll { $0 == .dropbox || $0 == .folder }
        }
        if currentDirectory.visibility == .isTeamSpaceFolder || currentDirectory.visibility == .isInTeamSpaceFolder {
            content.removeAll { $0 == .commonFolder }
        }
        tableView.reloadData()
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: FolderTypeTableViewCell.self, for: indexPath)
        cell.initWithPositionAndShadow(isFirst: true, isLast: true, radius: 6)
        switch content[indexPath.row] {
        case .folder:
            cell.titleLabel.text = KDriveStrings.Localizable.allFolder
            cell.accessoryImageView.image = KDriveAsset.folderFilled.image
            cell.descriptionLabel.text = KDriveStrings.Localizable.folderDescription
        case .commonFolder:
            cell.titleLabel.text = KDriveStrings.Localizable.commonFolderTitle
            cell.accessoryImageView.image = KDriveAsset.folderCommonDocuments.image
            cell.descriptionLabel.attributedText = NSMutableAttributedString(string: KDriveStrings.Localizable.commonFolderDescription(driveFileManager.drive.name), boldText: driveFileManager.drive.name)
        case .dropbox:
            cell.titleLabel.text = KDriveStrings.Localizable.dropBoxTitle
            cell.accessoryImageView.image = KDriveAsset.folderDropBox.image
            cell.descriptionLabel.text = KDriveStrings.Localizable.dropBoxDescription
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if content[indexPath.row] == .dropbox && (driveFileManager.drive.pack == .free || driveFileManager.drive.pack == .solo) {
            let floatingPanelViewController = DropBoxFloatingPanelViewController.instantiatePanel()
            (floatingPanelViewController.contentViewController as? DropBoxFloatingPanelViewController)?.actionHandler = { [weak self] _ in
                guard let self = self else { return }
                UIConstants.showStore(from: self, driveFileManager: self.driveFileManager)
            }
            present(floatingPanelViewController, animated: true)
            return
        } else {
            performSegue(withIdentifier: "toNewFolderSegue", sender: indexPath.row)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let row = sender as! Int
        let newFolderViewController = segue.destination as! NewFolderViewController
        newFolderViewController.driveFileManager = driveFileManager
        newFolderViewController.currentDirectory = currentDirectory
        newFolderViewController.folderType = content[row]
    }

    class func instantiateInNavigationController(parentDirectory: File, driveFileManager: DriveFileManager) -> TitleSizeAdjustingNavigationController {
        let newFolderViewController = instantiate()
        newFolderViewController.driveFileManager = driveFileManager
        newFolderViewController.currentDirectory = parentDirectory
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: newFolderViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    private class func instantiate() -> NewFolderTypeTableViewController {
        return Storyboard.newFolder.instantiateViewController(withIdentifier: "NewFolderTypeTableViewController") as! NewFolderTypeTableViewController
    }
}
