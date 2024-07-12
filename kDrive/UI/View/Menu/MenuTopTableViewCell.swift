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
import InfomaniakDI
import kDriveCore
import kDriveResources
import UIKit

class MenuTopTableViewCell: UITableViewCell {
    @IBOutlet var userAvatarContainerView: UIView!
    @IBOutlet var userAvatarImageView: UIImageView!
    @IBOutlet var userDisplayNameLabel: UILabel!
    @IBOutlet var userEmailLabel: UILabel!
    @IBOutlet var driveNameLabel: UILabel!
    @IBOutlet var driveImageView: UIImageView!
    @IBOutlet var switchDriveButton: UIButton!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var progressLabel: UILabel!

    @LazyInjectService var accountManager: AccountManageable

    func configureCell(with drive: Drive, and account: Account) {
        userAvatarContainerView.clipsToBounds = false
        userAvatarContainerView.layer.shadowOpacity = 0.3
        userAvatarContainerView.layer.shadowOffset = .zero
        userAvatarContainerView.layer.shadowRadius = 15
        userAvatarContainerView.layer.cornerRadius = userAvatarContainerView.frame.width / 2
        userAvatarContainerView.layer.shadowPath = UIBezierPath(ovalIn: userAvatarContainerView.bounds).cgPath
        // User image rounded
        userAvatarImageView.clipsToBounds = true
        userAvatarImageView.layer.cornerRadius = userAvatarImageView.frame.width / 2

        switchDriveButton.tintColor = KDriveResourcesAsset.primaryTextColor.color
        switchDriveButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonSwitchDrive
        switchDriveButton.isHidden = accountManager.drives.count <= 1

        driveNameLabel.text = drive.name
        driveImageView.tintColor = UIColor(hex: drive.preferences.color)
        userDisplayNameLabel.text = account.user.displayName
        userEmailLabel.text = account.user.email
        userAvatarImageView.image = KDriveResourcesAsset.placeholderAvatar.image
        account.user.getAvatar(size: CGSize(width: 512, height: 512)) { image in
            self.userAvatarImageView.image = image
        }

        if drive.size == 0 {
            progressView.isHidden = true
            progressLabel.isHidden = true
        } else {
            progressView.isHidden = false
            progressLabel.isHidden = false
            progressView.progress = Float(drive.usedSize) / Float(drive.size)
            progressLabel
                .text = "\(Constants.formatFileSize(drive.usedSize, decimals: 1)) / \(Constants.formatFileSize(drive.size))"
        }
    }
}
