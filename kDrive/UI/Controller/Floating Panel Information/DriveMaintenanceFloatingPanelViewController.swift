//
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

class DriveMaintenanceFloatingPanelViewController: InformationFloatingPanelViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = KDriveAsset.maintenance.image
        imageView.tintColor = KDriveAsset.iconColor.color
        animationView.isHidden = true
        titleLabel.text = KDriveStrings.Localizable.driveMaintenanceTitle(AccountManager.instance.currentDriveFileManager.drive.name)
        descriptionLabel.text = KDriveStrings.Localizable.driveMaintenanceDescription
        additionalInformationLabel.isHidden = true
        copyStackView.isHidden = true
        leftButton.isHidden = true
        rightButton.setTitle(KDriveStrings.Localizable.buttonClose, for: .normal)
    }
    
    override func rightButtonPressed(_ sender: UIButton) {
        floatingPanelViewController.dismiss(animated: true)
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = UIStoryboard(name: "InformationFloatingPanel", bundle: nil).instantiateViewController(withIdentifier: "InformationFloatingPanelViewController") as! InformationFloatingPanelViewController
        object_setClass(contentViewController, DriveMaintenanceFloatingPanelViewController.self)
        return contentViewController
    }
}
