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

    func configure(with shareable: Shareable, drive: Drive) {
        if let user = shareable as? DriveUser {
            configureWith(user: user, blocked: AccountManager.instance.currentUserId == user.id)
        } else if let invitation = shareable as? Invitation {
            configureWith(invitation: invitation)
        } else if let team = shareable as? Team {
            configureWith(team: team, drive: drive)
        }
    }

    func configureWith(user: DriveUser, blocked: Bool = false) {
        notAcceptedView.isHidden = true
        externalUserView.isHidden = user.type != .shared
        accessoryImageView.isHidden = blocked

        titleLabel.text = user.displayName
        detailLabel.text = user.email
        rightsLabel.text = user.permission?.title
        rightsLabel.textColor = blocked ? KDriveResourcesAsset.secondaryTextColor.color : KDriveResourcesAsset.titleColor.color
        user.getAvatar { image in
            self.avatarImage.image = image
                .resize(size: CGSize(width: 35, height: 35))
                .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                .withRenderingMode(.alwaysOriginal)
        }
    }

    func configureWith(invitation: Invitation) {
        notAcceptedView.isHidden = false
        externalUserView.isHidden = true

        titleLabel.text = invitation.displayName
        detailLabel.text = invitation.email
        rightsLabel.text = invitation.permission.title
        avatarImage.image = KDriveResourcesAsset.circleSend.image
        if let avatar = invitation.avatar, let url = URL(string: avatar) {
            KingfisherManager.shared.retrieveImage(with: url) { result in
                if let image = try? result.get().image {
                    self.avatarImage.image = image
                        .resize(size: CGSize(width: 35, height: 35))
                        .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                        .withRenderingMode(.alwaysOriginal)
                }
            }
        } else {
            avatarImage.image = KDriveResourcesAsset.placeholderAvatar.image
        }
    }

    func configureWith(team: Team, drive: Drive) {
        notAcceptedView.isHidden = true
        externalUserView.isHidden = true

        titleLabel.text = team.isAllUsers ? KDriveResourcesStrings.Localizable.allAllDriveUsers : team.name
        avatarImage.image = team.icon
        if let savedTeam = DriveInfosManager.instance.getTeam(id: team.id) {
            detailLabel.text = KDriveResourcesStrings.Localizable.shareUsersCount(savedTeam.usersCount(in: drive))
        } else {
            detailLabel.text = nil
        }
        rightsLabel.text = team.right?.title
        rightsLabel.textColor = KDriveResourcesAsset.titleColor.color
    }
}
