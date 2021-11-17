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
import InfomaniakCore

class CopyToOtherDriveViewController: SaveFileViewController {
    var sourceFile: File!
    override func didClickOnButton() {
        let footer = tableView.footerView(forSection: sections.count - 1) as! FooterButtonView
        footer.footerButton.setLoading(true)
        guard let selectedDriveFileManager = selectedDriveFileManager,
              let selectedDirectory = selectedDirectory else {
            footer.footerButton.setLoading(false)
            return
        }

        selectedDriveFileManager.apiFetcher.copyFileToAnotherDrive(destinationFile: selectedDirectory, sourceFile: sourceFile) { response, error in
            footer.footerButton.setLoading(false)
            if let error = error {
                // TODO: correctly handle error
                UIConstants.showSnackBar(message: "!External copy in progress")
            } else {
                self.dismiss(animated: true)
            }
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager?) -> CopyToOtherDriveViewController {
        let viewController = Storyboard.saveFile.instantiateViewController(withIdentifier: "CopyToOtherDriveViewController") as! CopyToOtherDriveViewController
        viewController.selectedDriveFileManager = driveFileManager
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
