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

class ShareFloatingPanelViewController: InformationFloatingPanelViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = KDriveAsset.folderDropBox.image
        animationView.isHidden = true
        titleLabel.text = KDriveStrings.Localizable.dropBoxResultTitle("")
        descriptionLabel.text = KDriveStrings.Localizable.dropBoxResultDescription
        additionalInformationLabel.isHidden = true
        leftButton.isHidden = true
        rightButton.setTitle(KDriveStrings.Localizable.buttonLater, for: .normal)
    }

    override func rightButtonPressed(_ sender: UIButton) {
        floatingPanelViewController.dismiss(animated: true)
        if let newFolderViewController = (presentingViewController as? UINavigationController)?.viewControllers.last as? NewFolderViewController {
            newFolderViewController.dismissAndRefreshDataSource()
        } else {
            #if !ISEXTENSION
                if let viewController = ((presentingViewController as? UITabBarController)?.selectedViewController as? UINavigationController)?.viewControllers.last as? ManageDropBoxViewController {
                    viewController.dismissAndRefreshDataSource()
                } else {
                    presentingViewController?.dismiss(animated: true)
                }
            #else
                presentingViewController?.dismiss(animated: true)
            #endif
        }
    }

    override class func instantiate() -> InformationFloatingPanelViewController {
        let contentViewController = Storyboard.informationFloatingPanel.instantiateViewController(withIdentifier: "InformationFloatingPanelViewController") as! InformationFloatingPanelViewController
        object_setClass(contentViewController, ShareFloatingPanelViewController.self)
        return contentViewController
    }

}
