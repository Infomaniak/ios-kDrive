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
import Lottie
import UIKit

class MigratePhotoSyncSettingsFloatingPanelViewController: InformationFloatingPanelViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = KDriveResourcesAsset.info.image
        imageViewHeightConstraint.constant = 50
        imageView.tintColor = KDriveResourcesAsset.iconColor.color
        animationView.isHidden = true
        titleLabel.text = KDriveResourcesStrings.Localizable.migratePhotoSyncSettingsTitle
        descriptionLabel.text = KDriveResourcesStrings.Localizable.migratePhotoSyncSettingsDescription
        additionalInformationLabel.isHidden = true
        copyStackView.isHidden = true
        leftButton.isHidden = true
        rightButton.setTitle(KDriveResourcesStrings.Localizable.buttonConfigure, for: .normal)
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = Storyboard.informationFloatingPanel.instantiateViewController(withIdentifier: "InformationFloatingPanelViewController") as! InformationFloatingPanelViewController
        object_setClass(contentViewController, MigratePhotoSyncSettingsFloatingPanelViewController.self)
        return contentViewController
    }
}
