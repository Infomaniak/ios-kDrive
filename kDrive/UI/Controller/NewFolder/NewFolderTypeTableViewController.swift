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

import InfomaniakCoreUIKit
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class NewFolderTypeTableViewController: UITableViewController {
    private lazy var packId = DrivePackId(rawValue: driveFileManager.drive.pack.name)

    @LazyInjectService private var router: AppNavigable

    var driveFileManager: DriveFileManager!
    var currentDirectory: File!

    private var content = [FolderType]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cellView: FolderTypeTableViewCell.self)
        tableView.separatorColor = .clear

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(closeButtonPressed)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.largeTitleDisplayMode = .always

        title = KDriveResourcesStrings.Localizable.newFolderTitle
        navigationItem.hideBackButtonText()

        setupFolderType()
    }

    func setupFolderType() {
        content = []
        // We can create a private folder if we are not in a team space
        if currentDirectory.visibility != .isTeamSpace {
            content.append(.folder)
        }
        // We can create a common folder if we have a pro or team drive and the create team folder right
        if driveFileManager.drive.capabilities.useTeamSpace && currentDirectory
            .visibility != .isTeamSpaceFolder && currentDirectory
            .visibility != .isInTeamSpaceFolder {
            content.append(.commonFolder)
        }
        // We can create a dropbox if we are not in a team space and not in a shared with me or the drive supports dropboxes
        if currentDirectory
            .visibility != .isTeamSpace &&
            (!driveFileManager.drive.sharedWithMe || driveFileManager.drive.pack.capabilities.useDropbox) {
            content.append(.dropbox)
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
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.allFolder
            cell.accessoryImageView.image = KDriveResourcesAsset.folderFilled.image
            cell.descriptionLabel.text = KDriveResourcesStrings.Localizable.folderDescription
        case .commonFolder:
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.commonFolderTitle
            cell.accessoryImageView.image = KDriveResourcesAsset.folderCommonDocuments.image
            cell.descriptionLabel.attributedText = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable.commonFolderDescription(driveFileManager.drive.name),
                boldText: driveFileManager.drive.name
            )
        case .dropbox:
            cell.titleLabel.text = KDriveResourcesStrings.Localizable.dropBoxTitle
            cell.accessoryImageView.image = KDriveResourcesAsset.folderDropBox.image
            cell.descriptionLabel.text = KDriveResourcesStrings.Localizable.dropBoxDescription
            if packId == .myKSuite, driveFileManager.drive.dropboxQuotaExceeded {
                cell.setMykSuiteChip()
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if content[indexPath.row] == .dropbox {
            if packId == .myKSuite, driveFileManager.drive.dropboxQuotaExceeded {
                router.presentUpSaleSheet()
            } else if !driveFileManager.drive.pack.capabilities.useDropbox {
                let driveFloatingPanelController = DropBoxFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController
                    .contentViewController as? DropBoxFloatingPanelViewController
                floatingPanelViewController?.rightButton.isEnabled = driveFileManager.drive.accountAdmin
                floatingPanelViewController?.actionHandler = { _ in
                    driveFloatingPanelController.dismiss(animated: true) { [weak self] in
                        guard let self else { return }
                        router.presentUpSaleSheet()
                    }
                }
                present(driveFloatingPanelController, animated: true)
            }
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

    class func instantiateInNavigationController(parentDirectory: File,
                                                 driveFileManager: DriveFileManager) -> TitleSizeAdjustingNavigationController {
        let newFolderViewController = instantiate()
        newFolderViewController.driveFileManager = driveFileManager
        newFolderViewController.currentDirectory = parentDirectory
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: newFolderViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    private class func instantiate() -> NewFolderTypeTableViewController {
        return Storyboard.newFolder
            .instantiateViewController(withIdentifier: "NewFolderTypeTableViewController") as! NewFolderTypeTableViewController
    }
}
