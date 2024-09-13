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

import FloatingPanel
import kDriveCore
import Lottie
import UIKit

class InformationFloatingPanelViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var animationView: AnimationView!
    @IBOutlet var animationViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var additionalInformationLabel: UILabel!
    @IBOutlet var copyStackView: UIStackView!
    @IBOutlet var copyTextField: UITextField!
    @IBOutlet var leftButton: UIButton!
    @IBOutlet var rightButton: UIButton!

    var floatingPanelViewController: DriveFloatingPanelController!

    var cancelHandler: ((UIButton) -> Void)?
    var actionHandler: ((UIButton) -> Void)?

    var drive: Drive?

    override func viewDidLoad() {
        super.viewDidLoad()
        leftButton.titleLabel?.numberOfLines = 2
        leftButton.titleLabel?.textAlignment = .center
        rightButton.titleLabel?.numberOfLines = 2
        rightButton.titleLabel?.textAlignment = .center
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animationView.play()
    }

    @IBAction func copyButtonPressed(_ sender: UIButton) {
        let items = [URL(string: copyTextField.text!)!]
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        ac.popoverPresentationController?.sourceView = sender
        present(ac, animated: true)
    }

    @IBAction func leftButtonPressed(_ sender: UIButton) {
        if let cancelHandler {
            cancelHandler(sender)
        } else {
            floatingPanelViewController.dismiss(animated: true)
        }
    }

    @IBAction func rightButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }

    class func instantiate() -> InformationFloatingPanelViewController {
        return Storyboard.informationFloatingPanel
            .instantiateViewController(
                withIdentifier: "InformationFloatingPanelViewController"
            ) as! InformationFloatingPanelViewController
    }

    class func instantiatePanel(drive: Drive? = nil) -> DriveFloatingPanelController {
        let contentVC = instantiate()
        contentVC.drive = drive

        let floatingPanelViewController = DriveFloatingPanelController()
        floatingPanelViewController.layout = InformationViewFloatingPanelLayout()
        floatingPanelViewController.surfaceView.grabberHandle.isHidden = true
        floatingPanelViewController.set(contentViewController: contentVC)
        contentVC.floatingPanelViewController = floatingPanelViewController
        return floatingPanelViewController
    }
}
