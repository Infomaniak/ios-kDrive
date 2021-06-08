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
import FloatingPanel
import Lottie
import kDriveCore

class InformationFloatingPanelViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var additionalInformationLabel: UILabel!
    @IBOutlet weak var copyStackView: UIStackView!
    @IBOutlet weak var copyTextField: UITextField!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!

    var floatingPanelViewController: DriveFloatingPanelController!

    var cancelHandler: ((UIButton) -> Void)?
    var actionHandler: ((UIButton) -> Void)?
    
    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animationView.play()
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        UIPasteboard.general.string = copyTextField.text
        UIConstants.showSnackBar(message: KDriveStrings.Localizable.fileInfoLinkCopiedToClipboard)
    }

    @IBAction func leftButtonPressed(_ sender: UIButton) {
        if let cancelHandler = cancelHandler {
            cancelHandler(sender)
        } else {
            floatingPanelViewController.dismiss(animated: true)
        }
    }

    @IBAction func rightButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }

    class func instantiate() -> InformationFloatingPanelViewController {
        return Storyboard.informationFloatingPanel.instantiateViewController(withIdentifier: "InformationFloatingPanelViewController") as! InformationFloatingPanelViewController
    }

    class func instantiatePanel() -> DriveFloatingPanelController {
        let contentVC = instantiate()

        let floatingPanelViewController = DriveFloatingPanelController()
        floatingPanelViewController.layout = InformationViewFloatingPanelLayout()
        floatingPanelViewController.surfaceView.grabberHandle.isHidden = true
        floatingPanelViewController.set(contentViewController: contentVC)
        contentVC.floatingPanelViewController = floatingPanelViewController
        return floatingPanelViewController
    }
}
