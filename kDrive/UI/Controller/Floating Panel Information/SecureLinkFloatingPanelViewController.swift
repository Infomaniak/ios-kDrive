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

class SecureLinkFloatingPanelViewController: InformationFloatingPanelViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.isHidden = true
        animationView.animation = Animation.named("illu_upgrade")
        titleLabel.text = KDriveStrings.Localizable.secureLinkShareTitle
        descriptionLabel.text = KDriveStrings.Localizable.secureLinkShareDescription
        let teams = "Solo, Team & Pro"
        additionalInformationLabel.attributedText = NSMutableAttributedString(string: KDriveStrings.Localizable.allPackAvailability(teams), highlightedText: teams)
        copyStackView.isHidden = true
        leftButton.setTitle(KDriveStrings.Localizable.buttonLater, for: .normal)
        rightButton.setTitle(KDriveStrings.Localizable.buttonUpgradeOffer, for: .normal)
        rightButton?.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        rightButton.titleLabel?.textAlignment = NSTextAlignment.center
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = UIStoryboard(name: "InformationFloatingPanel", bundle: nil).instantiateViewController(withIdentifier: "InformationFloatingPanelViewController") as! InformationFloatingPanelViewController
        object_setClass(contentViewController, SecureLinkFloatingPanelViewController.self)
        return contentViewController
    }

}
