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

import InfomaniakCore
import InfomaniakLogin
import kDriveCore
import kDriveResources
import UIKit

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
        if let navigationController = view.window?.rootViewController as? UINavigationController {
            return navigationController.visibleViewController == self
        } else {
            return view.window?.rootViewController == self
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hideBackButtonText()

        setupView()
        setupCircleView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setInfomaniakAppearanceNavigationBar()
    }

    @IBAction func testButtonPressed(_ sender: Any) {
        UIApplication.shared.open(URLConstants.shop.url)
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
            imageView.image = KDriveResourcesAsset.noDrive.image
            titleLabel.text = KDriveResourcesStrings.Localizable.noDriveTitle
            descriptionLabel.text = KDriveResourcesStrings.Localizable.noDriveDescription
        case .maintenance:
            imageView.image = KDriveResourcesAsset.maintenance.image
            imageView.tintColor = KDriveResourcesAsset.iconColor.color
            if let driveName = driveName {
                titleLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceTitle(driveName)
            } else {
                titleLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceTitlePlural
            }
            descriptionLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceDescription
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
