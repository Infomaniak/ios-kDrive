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

import kDriveCore
import kDriveResources
import UIKit

protocol FileCommentDelegate: AnyObject {
    func didLikeComment(comment: Comment, index: Int)
    func showLikesPopover(comment: Comment, index: Int)
}

class FileDetailCommentTableViewCell: UITableViewCell {
    @IBOutlet var userAvatar: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var likeImage: UIImageView!
    @IBOutlet var likeLabel: UILabel!
    @IBOutlet var likesView: UIStackView!
    @IBOutlet var commentLeadingConstraint: NSLayoutConstraint!
    weak var commentDelegate: FileCommentDelegate?
    var comment: Comment!
    var index: Int!

    override func awakeFromNib() {
        super.awakeFromNib()

        let tap = UITapGestureRecognizer(target: self, action: #selector(likeButton))
        likeImage.addGestureRecognizer(tap)
        likeImage.accessibilityTraits = .button
        likeImage.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonLike
        userAvatar.image = KDriveResourcesAsset.placeholderAvatar.image

        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressureLikeButton))
        likesView.addGestureRecognizer(longGesture)
        likeImage.tintAdjustmentMode = .normal
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        userAvatar.image = KDriveResourcesAsset.placeholderAvatar.image
        likeImage.tintAdjustmentMode = .normal
    }

    func configureWith(comment: Comment, index: Int, response: Bool = false) {
        self.comment = comment
        self.index = index
        comment.user.getAvatar { image in
            self.userAvatar.image = image
                .resize(size: CGSize(width: 35, height: 35))
                .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                .withRenderingMode(.alwaysOriginal)
        }
        userNameLabel.text = comment.user.displayName
        descriptionLabel.text = comment.body
        timeLabel.text = Constants.formatDate(comment.createdAt, relative: true)
        likeLabel.text = "\(comment.likesCount)"
        likeLabel.textColor = comment.liked ? KDriveResourcesAsset.infomaniakColor.color : KDriveResourcesAsset.iconColor.color
        likeImage.tintColor = comment.liked ? KDriveResourcesAsset.infomaniakColor.color : KDriveResourcesAsset.iconColor.color
        commentLeadingConstraint.constant = response ? 48 : 24
    }

    @objc func likeButton() {
        commentDelegate?.didLikeComment(comment: comment, index: index)
        likeImage.tintColor = !comment.liked ? KDriveResourcesAsset.infomaniakColor.color : KDriveResourcesAsset.iconColor.color
        likeLabel.textColor = !comment.liked ? KDriveResourcesAsset.infomaniakColor.color : KDriveResourcesAsset.iconColor.color
        likeLabel.text = !comment.liked ? "\(comment.likesCount + 1)" : "\(comment.likesCount - 1)"
    }

    @objc func longPressureLikeButton() {
        if comment.likesCount > 0 {
            commentDelegate?.showLikesPopover(comment: comment, index: index)
        }
    }
}
