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
import InfomaniakCoreCommonUI
import InfomaniakDI
import InfomaniakLogin
import kDriveCore
import kDriveResources
import UIKit

class DriveErrorViewController: UIViewController {
    enum DriveErrorViewType {
        case noDrive
        case maintenance
        case blocked
    }

    @IBOutlet var circleView: UIView!
    @IBOutlet var otherProfileButton: UIButton!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var mainButton: IKLargeButton!

    @LazyInjectService private var matomo: MatomoUtils

    var driveErrorViewType = DriveErrorViewType.noDrive
    var driveName: String?
    var updatedAt: Date?
    var drive: Drive?

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        matomo.track(view: ["DriveError"])
    }

    @IBAction func mainButtonPressed(_ sender: Any) {
        if driveErrorViewType == .noDrive {
            UIApplication.shared.open(URLConstants.shop.url)
        } else if driveErrorViewType == .blocked {
            UIApplication.shared.open(URLConstants.renewDrive(accountId: drive!.accountId).url)
        } else if let drive, drive.isAsleep {
            UIApplication.shared.open(URLConstants.kDriveWeb.url)
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
            imageView.image = KDriveResourcesAsset.noDrive.image
            titleLabel.text = KDriveResourcesStrings.Localizable.noDriveTitle
            descriptionLabel.text = KDriveResourcesStrings.Localizable.noDriveDescription
            mainButton.setTitle(KDriveResourcesStrings.Localizable.buttonNoDriveFreeTest, for: .normal)
        case .maintenance:
            imageView.image = KDriveResourcesAsset.maintenance.image
            imageView.tintColor = KDriveResourcesAsset.iconColor.color
            if let drive, drive.isAsleep {
                titleLabel.text = KDriveResourcesStrings.Localizable.maintenanceAsleepTitle(drive.name)
                descriptionLabel.text = KDriveResourcesStrings.Localizable.maintenanceAsleepDescription
                mainButton.setTitle(KDriveResourcesStrings.Localizable.maintenanceWakeUpButton, for: .normal)
            } else {
                if let driveName {
                    titleLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceTitle(driveName)
                } else {
                    titleLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceTitlePlural
                }
                descriptionLabel.text = KDriveResourcesStrings.Localizable.driveMaintenanceDescription
                mainButton.isHidden = true
            }
        case .blocked:
            imageView.image = KDriveResourcesAsset.driveBlocked.image
            mainButton.isHidden = true
            if let drive {
                titleLabel.text = KDriveResourcesStrings.Localizable.driveBlockedTitle(drive.name)
                descriptionLabel.text = KDriveResourcesStrings.Localizable.driveBlockedDescription(Constants.formatDate(
                    drive.updatedAt,
                    style: .date
                ))
                if drive.isUserAdmin {
                    mainButton.isHidden = false
                    mainButton.setTitle(KDriveResourcesStrings.Localizable.buttonRenew, for: .normal)
                }
            } else {
                titleLabel.text = KDriveResourcesStrings.Localizable.driveBlockedTitlePlural
                descriptionLabel.text = KDriveResourcesStrings.Localizable.driveBlockedDescriptionPlural
            }
        }
    }

    private func setupCircleView() {
        circleView.cornerRadius = circleView.bounds.width / 2
    }

    class func instantiate(errorType: DriveErrorViewType, drive: Drive?) -> DriveErrorViewController {
        let driveErrorViewController = Storyboard.main
            .instantiateViewController(withIdentifier: "DriveErrorViewController") as! DriveErrorViewController
        driveErrorViewController.driveErrorViewType = errorType
        driveErrorViewController.drive = drive
        return driveErrorViewController
    }

    class func instantiateInNavigationController(errorType: DriveErrorViewType, drive: Drive?) -> UINavigationController {
        let driveErrorViewController = instantiate(errorType: errorType, drive: drive)
        let navigationController = UINavigationController(rootViewController: driveErrorViewController)
        navigationController.setInfomaniakAppearanceNavigationBar()
        return navigationController
    }
}
