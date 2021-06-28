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
import InfomaniakLogin
import InfomaniakCore
import kDriveCore

class DriveErrorViewController: UIViewController {

    enum DriveErrorViewType {
        case noDrive
        case maintenance
    }

    @IBOutlet weak var circleView: UIView!
    @IBOutlet weak var otherProfileButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var mainButton: IKLargeButton!

    var driveErrorViewType = DriveErrorViewType.noDrive
    var driveName: String?

    var isRootViewController: Bool {
        if let navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController {
            return navigationController.visibleViewController == self
        } else {
            return UIApplication.shared.keyWindow?.rootViewController == self
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.backButtonTitle = ""

        setupView()
        setupCircleView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    @IBAction func testButtonPressed(_ sender: Any) {
        if let url = URL(string: ApiRoutes.orderDrive()) {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func otherProfileButtonPressed(_ sender: Any) {
        if isRootViewController {
            navigationController?.pushViewController(SwitchUserViewController.instantiate(), animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func setupView() {
        switch driveErrorViewType {
        case .noDrive:
            imageView.image = KDriveAsset.noDrive.image
            titleLabel.text = KDriveStrings.Localizable.noDriveTitle
            descriptionLabel.text = KDriveStrings.Localizable.noDriveDescription
        case .maintenance:
            imageView.image = KDriveAsset.maintenance.image
            imageView.tintColor = KDriveAsset.iconColor.color
            if let driveName = driveName {
                titleLabel.text = KDriveStrings.Localizable.driveMaintenanceTitle(driveName)
            } else {
                titleLabel.text = KDriveStrings.Localizable.driveMaintenanceTitlePlural
            }
            descriptionLabel.text = KDriveStrings.Localizable.driveMaintenanceDescription
            mainButton.isHidden = true
        }
    }

    private func setupCircleView() {
        circleView.cornerRadius = circleView.bounds.width / 2
    }

    class func instantiate() -> DriveErrorViewController {
        return Storyboard.main.instantiateViewController(withIdentifier: "DriveErrorViewController") as! DriveErrorViewController
    }

    class func instantiateInNavigationController() -> UINavigationController {
        let driveErrorViewController = instantiate()
        let navigationController = UINavigationController(rootViewController: driveErrorViewController)
        navigationController.setInfomaniakAppearanceNavigationBar()
        return navigationController
    }

}
