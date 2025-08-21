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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

class InsufficientStorageCollectionViewCell: InsetCollectionViewCell {
    @IBOutlet var progressView: RPCircularProgress!
    @IBOutlet var storageLabel: UILabel!
    @IBOutlet var storageDescription: UILabel!
    @IBOutlet var upgradeLabel: UILabel!
    @IBOutlet var upgradeButton: UIButton!

    var actionHandler: ((UIButton) -> Void)?
    var closeHandler: ((UIButton) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        upgradeButton.isHidden = true
        upgradeLabel.isHidden = true

        progressView.setInfomaniakStyle()
        progressView.progressTintColor = KDriveResourcesAsset.binColor.color
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        storageDescription.text = nil
        upgradeButton.isHidden = true
        upgradeLabel.isHidden = true
    }

    func configureCell(with driveFileManager: DriveFileManager) {
        let drive = driveFileManager.drive
        progressView.updateProgress(CGFloat(drive.usedSize) / CGFloat(drive.size))

        storageLabel
            .text =
            "\(Constants.formatFileSize(drive.usedSize, decimals: 1, unit: false)) / \(Constants.formatFileSize(drive.size))"

        guard drive.pack.drivePackId == .kSuiteEntreprise else {
            configureCell(drive: drive)
            return
        }

        configureKSuiteEnterpriseCell(drive: drive)
    }

    func configureCell(drive: Drive) {
        if drive.accountAdmin {
            storageDescription.text = KDriveResourcesStrings.Localizable.notEnoughStorageDescription1
            upgradeButton.isHidden = false
        } else {
            storageDescription.text = KDriveResourcesStrings.Localizable.notEnoughStorageDescription2
            upgradeButton.isHidden = true
        }
    }

    func configureKSuiteEnterpriseCell(drive: Drive) {
        upgradeButton.isHidden = true
        upgradeLabel.isHidden = false
        if drive.isUserAdmin {
            upgradeLabel.text = "TODO: i18n - Upgrade on the website"
        } else {
            upgradeLabel.text = "TODO: i18n - Contact Admin to upgrade"
        }
    }

    @IBAction func closeButtonPressed(_ sender: UIButton) {
        closeHandler?(sender)
    }

    @IBAction func upgradeButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
