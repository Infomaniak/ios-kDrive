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


class FolderColorFloatingPanelViewController: InformationFloatingPanelViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.isHidden = true
        animationView.animation = Animation.named("illu_upgrade")
        animationViewHeightConstraint.constant = 105
        titleLabel.text = KDriveResourcesStrings.Localizable.folderColorTitle
        descriptionLabel.text = KDriveResourcesStrings.Localizable.folderColorDescription
        additionalInformationLabel.attributedText = NSMutableAttributedString(
            string: KDriveResourcesStrings.Localizable.allPackAvailability,
            highlightedText: Constants.kDriveTeams
        )
        copyStackView.isHidden = true
        leftButton.setTitle(KDriveResourcesStrings.Localizable.buttonLater, for: .normal)
        rightButton.setTitle(KDriveResourcesStrings.Localizable.buttonUpgradeOffer, for: .normal)
        rightButton?.titleLabel?.lineBreakMode = .byWordWrapping
        rightButton.titleLabel?.textAlignment = .center
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = Storyboard.informationFloatingPanel
            .instantiateViewController(
                withIdentifier: "InformationFloatingPanelViewController"
            ) as! InformationFloatingPanelViewController
        object_setClass(contentViewController, FolderColorFloatingPanelViewController.self)
        return contentViewController
    }
}
