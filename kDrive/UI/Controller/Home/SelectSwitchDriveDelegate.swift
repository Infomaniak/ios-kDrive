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
import kDriveResources
import UIKit

@MainActor
protocol SelectSwitchDriveDelegate: SelectDelegate, UIViewController {}
extension SelectSwitchDriveDelegate {
    func didSelect(option: Selectable) {
        guard let drive = option as? Drive else { return }
        if drive.maintenance {
            let driveFloatingPanelController = DriveMaintenanceFloatingPanelViewController.instantiatePanel()
            let floatingPanelViewController = driveFloatingPanelController.contentViewController as? DriveMaintenanceFloatingPanelViewController
            floatingPanelViewController?.setTitleLabel(with: drive.name)
            present(driveFloatingPanelController, animated: true)
        } else {
            AccountManager.instance.setCurrentDriveForCurrentAccount(drive: drive)
            AccountManager.instance.saveAccounts()
            // Download root file
            guard let currentDriveFileManager = AccountManager.instance.currentDriveFileManager else {
                return
            }

            Task {
                // Download root files
                try await currentDriveFileManager.initRoot()
                (tabBarController as? SwitchDriveDelegate)?.didSwitchDriveFileManager(newDriveFileManager: currentDriveFileManager)
            }
        }
    }
}

extension Drive: Selectable {
    var title: String {
        return name
    }

    var image: UIImage? {
        return KDriveResourcesAsset.drive.image
    }

    var tintColor: UIColor? {
        return UIColor(hex: preferences.color)
    }
}
