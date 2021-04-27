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
import InfomaniakCore
import kDriveCore

class InsufficientStorageTableViewCell: InsetTableViewCell {

    @IBOutlet weak var progressView: RPCircularProgress!
    @IBOutlet weak var storageLabel: UILabel!
    @IBOutlet weak var storageDescription: UILabel!
    @IBOutlet weak var upgradeButton: UIButton!

    var actionHandler: ((UIButton) -> Void)?
    var closeHandler: ((UIButton) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        progressView.trackTintColor = KDriveAsset.secondaryTextColor.color.withAlphaComponent(0.2)
        progressView.progressTintColor = KDriveAsset.binColor.color
        progressView.thicknessRatio = 0.15
        progressView.indeterminateProgress = 0.75
    }

    func configureCell(with drive: Drive) {
        progressView.updateProgress(CGFloat(drive.usedSize) / CGFloat(drive.size))

        storageLabel.text = "\(Constants.formatFileSize(drive.usedSize, decimals: 1, unit: false)) / \(Constants.formatFileSize(drive.size))"

        if drive.isProOrTeam {
            storageDescription.text = KDriveStrings.Localizable.notEnoughStorageDescription2
            upgradeButton.isHidden = true
        } else {
            storageDescription.text = KDriveStrings.Localizable.notEnoughStorageDescription1
            upgradeButton.isHidden = false
        }
    }

    @IBAction func closeButtonPressed(_ sender: UIButton) {
        closeHandler?(sender)
    }

    @IBAction func upgradeButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
