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

class DriveMaintenanceFloatingPanelViewController: InformationFloatingPanelViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        imageViewHeightConstraint.constant = 70
        imageView.tintColor = KDriveResourcesAsset.iconColor.color
        animationView.isHidden = true
        additionalInformationLabel.isHidden = true
        copyStackView.isHidden = true
        rightButton.setTitle(KDriveResourcesStrings.Localizable.buttonClose, for: .normal)
        leftButton.isHidden = true

        if let drive, !drive.isInTechnicalMaintenance {
            titleLabel.text = KDriveResourcesStrings.Localizable.driveBlockedTitle(drive.name)
            imageView.image = KDriveResourcesAsset.driveBlocked.image
            descriptionLabel.text = KDriveResourcesStrings.Localizable.driveBlockedDescription(Constants.formatDate(
                drive.updatedAt,
                style: .date
            ))
            #if !ISEXTENSION
            if drive.isUserAdmin {
                leftButton.setTitle(KDriveResourcesStrings.Localizable.buttonRenew, for: .normal)
                leftButton.isHidden = false
            }
            #endif
        } else if let drive, drive.isAsleep {
            titleLabel.text = KDriveResourcesStrings.Localizable.maintenanceAsleepTitle(drive.name)
            imageView.image = KDriveResourcesAsset.maintenance.image
            descriptionLabel.text = KDriveResourcesStrings.Localizable.maintenanceAsleepDescription
            #if !ISEXTENSION
            leftButton.setTitle(KDriveResourcesStrings.Localizable.maintenanceWakeUpButton, for: .normal)
            leftButton.isHidden = false
            #endif
        } else {
            titleLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceTitle(drive?.name ?? "")
            imageView.image = KDriveResourcesAsset.maintenance.image
            descriptionLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceDescription
        }
    }

    #if !ISEXTENSION
    override func leftButtonPressed(_ sender: UIButton) {
        guard let drive else { return }
        if drive.isAsleep {
            UIApplication.shared.open(URLConstants.kDriveWeb.url)
        } else {
            UIApplication.shared.open(URLConstants.renewDrive(accountId: drive.accountId).url)
        }
    }
    #endif

    override func rightButtonPressed(_ sender: UIButton) {
        floatingPanelViewController.dismiss(animated: true)
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = Storyboard.informationFloatingPanel
            .instantiateViewController(
                withIdentifier: "InformationFloatingPanelViewController"
            ) as! InformationFloatingPanelViewController
        object_setClass(contentViewController, DriveMaintenanceFloatingPanelViewController.self)
        return contentViewController
    }
}
