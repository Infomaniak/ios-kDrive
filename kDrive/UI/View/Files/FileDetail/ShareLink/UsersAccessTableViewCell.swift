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
import kDriveCore
import kDriveResources
import Kingfisher
import UIKit

class UsersAccessTableViewCell: InsetTableViewCell {
    @IBOutlet weak var rightsStackView: UIStackView!
    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var rightsLabel: UILabel!
    @IBOutlet weak var notAcceptedView: UIView!
    @IBOutlet weak var externalUserView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        accessoryImageView.isHidden = false
        avatarImage.layer.cornerRadius = avatarImage.frame.height / 2
        avatarImage.clipsToBounds = true
        avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image
    }

    func configure(with element: FileAccessElement, drive: Drive) {
        titleLabel.text = element.name
        rightsLabel.text = element.right.title
        rightsLabel.textColor = KDriveResourcesAsset.titleColor.color
        accessoryImageView.isHidden = false

        Task {
            avatarImage.image = await element.icon
        }

        if let user = element as? UserFileAccess {
            let blocked = AccountManager.instance.currentUserId == user.id
            rightsLabel.textColor = blocked ? KDriveResourcesAsset.secondaryTextColor.color : KDriveResourcesAsset.titleColor.color
            detailLabel.text = user.email
            notAcceptedView.isHidden = true
            // FIXME: Wait to API v2 to return this value
            externalUserView.isHidden = true // user.type != .shared
            accessoryImageView.isHidden = blocked
        } else if let invitation = element as? ExternInvitationFileAccess {
            detailLabel.text = invitation.email
            notAcceptedView.isHidden = false
            externalUserView.isHidden = true
        } else if let team = element as? TeamFileAccess {
            titleLabel.text = team.isAllUsers ? KDriveResourcesStrings.Localizable.allAllDriveUsers : team.name
            if let savedTeam = DriveInfosManager.instance.getTeam(id: team.id) {
                detailLabel.text = KDriveResourcesStrings.Localizable.shareUsersCount(savedTeam.usersCount(in: drive))
            } else {
                detailLabel.text = nil
            }
            notAcceptedView.isHidden = true
            externalUserView.isHidden = true
        }
    }
}
