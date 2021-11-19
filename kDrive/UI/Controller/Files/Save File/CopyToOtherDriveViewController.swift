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

class CopyToOtherDriveViewController: SaveFileViewController {
    var sourceFile: File!
    var currentDriveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let defaultDrive = DriveInfosManager.instance.getDrives(for: currentDriveFileManager.drive.userId).first(where: { $0 != currentDriveFileManager.drive }) {
            selectedDriveFileManager = AccountManager.instance.getDriveFileManager(for: defaultDrive)
        }
        title = "!Copy to other drive"
    }

    override func didClickOnButton() {
        let footer = tableView.footerView(forSection: sections.count - 1) as! FooterButtonView
        footer.footerButton.setLoading(true)
        guard let selectedDriveFileManager = selectedDriveFileManager,
              let selectedDirectory = selectedDirectory else {
            footer.footerButton.setLoading(false)
            return
        }

        selectedDriveFileManager.apiFetcher.copyFileToAnotherDrive(destinationFile: selectedDirectory, sourceFile: sourceFile) { _, error in
            footer.footerButton.setLoading(false)
            if let error = error {
                // TODO: correctly handle error
                UIConstants.showSnackBar(message: "!External copy in progress")
            } else {
                self.dismiss(animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .driveSelection:
            let selectDriveViewController = SelectDriveViewController.instantiate()
            selectDriveViewController.accountSelectionEnabled = false
            if let currentDrive = currentDriveFileManager?.drive {
                selectDriveViewController.hiddenDriveList = [currentDrive]
            }
            selectDriveViewController.selectedDrive = selectedDriveFileManager?.drive
            selectDriveViewController.delegate = self
            navigationController?.pushViewController(selectDriveViewController, animated: true)
        default:
            super.tableView(tableView, didSelectRowAt: indexPath)
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager?) -> CopyToOtherDriveViewController {
        let viewController = Storyboard.saveFile.instantiateViewController(withIdentifier: "CopyToOtherDriveViewController") as! CopyToOtherDriveViewController
        viewController.currentDriveFileManager = driveFileManager
        return viewController
    }

    static func instantiateInNavigationController(driveFileManager: DriveFileManager?, sourceFile: File) -> TitleSizeAdjustingNavigationController {
        let saveViewController = instantiate(driveFileManager: driveFileManager)
        saveViewController.sourceFile = sourceFile
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: saveViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
}
