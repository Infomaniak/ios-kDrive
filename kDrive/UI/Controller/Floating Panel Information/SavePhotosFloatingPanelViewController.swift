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

class SavePhotosFloatingPanelViewController: InformationFloatingPanelViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.isHidden = true
        animationView.animation = LottieAnimation.named("illu_photos")
        animationViewHeightConstraint.constant = 258
        titleLabel.text = KDriveResourcesStrings.Localizable.syncConfigureTitle
        if let drive {
            descriptionLabel.attributedText = NSMutableAttributedString(
                string: KDriveResourcesStrings.Localizable.syncConfigureDescription(drive.name),
                boldText: drive.name
            )
        } else {
            descriptionLabel.text = nil
        }
        additionalInformationLabel.isHidden = true
        copyStackView.isHidden = true
        leftButton.setTitle(KDriveResourcesStrings.Localizable.buttonLater, for: .normal)
        rightButton.setTitle(KDriveResourcesStrings.Localizable.buttonConfigure, for: .normal)
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = Storyboard.informationFloatingPanel
            .instantiateViewController(
                withIdentifier: "InformationFloatingPanelViewController"
            ) as! InformationFloatingPanelViewController
        object_setClass(contentViewController, SavePhotosFloatingPanelViewController.self)
        return contentViewController
    }
}
