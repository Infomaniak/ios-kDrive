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

import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

@MainActor
protocol SelectSwitchDriveDelegate: SelectDelegate, UIViewController {}
extension SelectSwitchDriveDelegate {
    func didSelect(option: Selectable) {
        guard let drive = option as? Drive else { return }
        if drive.inMaintenance {
            let driveFloatingPanelController = DriveMaintenanceFloatingPanelViewController.instantiatePanel(drive: drive)
            present(driveFloatingPanelController, animated: true)
        } else {
            MatomoUtils.track(eventWithCategory: .drive, name: "switch")

            let driveId = drive.id
            let driveUserId = drive.userId

            Task {
                @InjectService var appRestorationService: AppRestorationServiceable
                await appRestorationService.reloadAppUI(for: driveId, userId: driveUserId)
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
