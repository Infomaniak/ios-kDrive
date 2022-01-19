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
        if let user = shareable as? UserFileAccess {
            configure(with: user, blocked: AccountManager.instance.currentUserId == user.id)
        } else if let invitation = shareable as? ExternInvitationFileAccess {
            configure(with: invitation)
        } else if let team = shareable as? TeamFileAccess {
            configure(with: team, drive: drive)
        }
    }

    func configure(with user: UserFileAccess, blocked: Bool) {
        notAcceptedView.isHidden = true
        // externalUserView.isHidden = user.type != .shared
        accessoryImageView.isHidden = blocked

        titleLabel.text = user.name
        detailLabel.text = user.email
        rightsLabel.text = user.right.title
        rightsLabel.textColor = blocked ? KDriveResourcesAsset.secondaryTextColor.color : KDriveResourcesAsset.titleColor.color
        user.user.getAvatar { image in
            self.avatarImage.image = image
                .resize(size: CGSize(width: 35, height: 35))
                .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                .withRenderingMode(.alwaysOriginal)
        }
    }

    func configure(with invitation: ExternInvitationFileAccess) {
        notAcceptedView.isHidden = false
        externalUserView.isHidden = true

        titleLabel.text = invitation.name
        detailLabel.text = invitation.email
        rightsLabel.text = invitation.right.title
        avatarImage.image = KDriveResourcesAsset.circleSend.image
        if let avatar = invitation.user?.avatar, let url = URL(string: avatar) {
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

    func configure(with team: TeamFileAccess, drive: Drive) {
        notAcceptedView.isHidden = true
        externalUserView.isHidden = true

        titleLabel.text = team.isAllUsers ? KDriveResourcesStrings.Localizable.allAllDriveUsers : team.name
        if let savedTeam = DriveInfosManager.instance.getTeam(id: team.id) {
            avatarImage.image = savedTeam.icon
            detailLabel.text = KDriveResourcesStrings.Localizable.shareUsersCount(savedTeam.usersCount(in: drive))
        } else {
            avatarImage.image = nil
            detailLabel.text = nil
        }
        rightsLabel.text = team.right.title
        rightsLabel.textColor = KDriveResourcesAsset.titleColor.color
    }
}
