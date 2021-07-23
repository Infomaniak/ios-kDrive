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
import Lottie

class DropBoxFloatingPanelViewController: InformationFloatingPanelViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.isHidden = true
        animationView.animation = Animation.named("illu_drop_box")
        animationViewHeightConstraint.constant = 130
        titleLabel.text = KDriveStrings.Localizable.dropBoxTitle
        descriptionLabel.text = KDriveStrings.Localizable.dropBoxDescription
        let teams = "Team & Pro"
        additionalInformationLabel.attributedText = NSMutableAttributedString(string: KDriveStrings.Localizable.allPackAvailability(teams), highlightedText: teams)
        copyStackView.isHidden = true
        leftButton.setTitle(KDriveStrings.Localizable.buttonLater, for: .normal)
        rightButton.setTitle(KDriveStrings.Localizable.buttonUpgradeOffer, for: .normal)
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = Storyboard.informationFloatingPanel.instantiateViewController(withIdentifier: "InformationFloatingPanelViewController") as! InformationFloatingPanelViewController
        object_setClass(contentViewController, DropBoxFloatingPanelViewController.self)
        return contentViewController
    }

}
