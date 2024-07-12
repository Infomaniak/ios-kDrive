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

import InfomaniakCoreUI
import kDriveCore
import kDriveResources
import LocalizeKit
import UIKit

class FileDetailActivityTableViewCell: InsetTableViewCell {
    @IBOutlet var detailLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        accessoryImageView.image = KDriveResourcesAsset.placeholderAvatar.image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accessoryImageView.image = KDriveResourcesAsset.placeholderAvatar.image
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        contentInsetView.backgroundColor = .clear
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentInsetView.backgroundColor = .clear
    }

    // swiftlint:disable:next cyclomatic_complexity
    func configure(with activity: FileActivity, file: File) {
        let user = activity.user
        titleLabel.text = user?.displayName ?? KDriveResourcesStrings.Localizable.allUserAnonymous

        if let user {
            user.getAvatar { image in
                self.accessoryImageView.image = image
                    .resize(size: CGSize(width: 35, height: 35))
                    .maskImageWithRoundedRect(cornerRadius: CGFloat(35 / 2), borderWidth: 0, borderColor: .clear)
                    .withRenderingMode(.alwaysOriginal)
            }
        }

        let localizedKey: String
        switch activity.action {
        case .fileAccess:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderAccess" : "fileDetailsActivityFileAccess"
        case .fileCreate:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderCreate" : "fileDetailsActivityFileCreate"
        case .fileRename:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderRename" : "fileDetailsActivityFileRename"
        case .fileTrash:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderTrash" : "fileDetailsActivityFileTrash"
        case .fileRestore:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderRestore" : "fileDetailsActivityFileRestore"
        case .fileDelete:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderDelete" : "fileDetailsActivityFileDelete"
        case .fileUpdate:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderUpdate" : "fileDetailsActivityFileUpdate"
        case .fileCategorize:
            localizedKey = "fileDetailsActivityFileCategorize"
        case .fileUncategorize:
            localizedKey = "fileDetailsActivityFileUncategorize"
        case .fileFavoriteCreate:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderFavoriteCreate" : "fileDetailsActivityFileFavoriteCreate"
        case .fileFavoriteRemove:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderFavoriteRemove" : "fileDetailsActivityFileFavoriteRemove"
        case .fileShareCreate:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderShareCreate" : "fileDetailsActivityFileShareCreate"
        case .fileShareUpdate:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderShareUpdate" : "fileDetailsActivityFileShareUpdate"
        case .fileShareDelete:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderShareDelete" : "fileDetailsActivityFileShareDelete"
        case .shareLinkCreate:
            localizedKey = file
                .isDirectory ? "fileDetailsActivityFolderShareLinkCreate" : "fileDetailsActivityFileShareLinkCreate"
        case .shareLinkUpdate:
            localizedKey = file
                .isDirectory ? "fileDetailsActivityFolderShareLinkUpdate" : "fileDetailsActivityFileShareLinkUpdate"
        case .shareLinkDelete:
            localizedKey = file
                .isDirectory ? "fileDetailsActivityFolderShareLinkDelete" : "fileDetailsActivityFileShareLinkDelete"
        case .shareLinkShow:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderShareLinkShow" : "fileDetailsActivityFileShareLinkShow"
        case .commentCreate:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderCommentCreate" : "fileDetailsActivityFileCommentCreate"
        case .commentUpdate:
            localizedKey = "fileDetailsActivityFileCommentUpdate"
        case .commentDelete:
            localizedKey = "fileDetailsActivityFileCommentDelete"
        case .commentLike:
            localizedKey = "fileDetailsActivityFileCommentLike"
        case .commentUnlike:
            localizedKey = "fileDetailsActivityFileCommentUnlike"
        case .commentResolve:
            localizedKey = "fileDetailsActivityFileCommentResolve"
        case .fileMoveIn, .fileMoveOut:
            localizedKey = file.isDirectory ? "fileDetailsActivityFolderMove" : "fileDetailsActivityFileMove"
        case .collaborativeFolderAccess:
            localizedKey = "fileActivityCollaborativeFolderAccess"
        case .collaborativeFolderCreate:
            localizedKey = "fileActivityCollaborativeFolderCreate"
        case .collaborativeFolderUpdate:
            localizedKey = "fileActivityCollaborativeFolderUpdate"
        case .collaborativeFolderDelete:
            localizedKey = "fileActivityCollaborativeFolderDelete"
        case .collaborativeUserAccess:
            localizedKey = "fileActivityCollaborativeUserAccess"
        case .collaborativeUserCreate:
            localizedKey = "fileActivityCollaborativeUserCreate"
        case .collaborativeUserDelete:
            localizedKey = "fileActivityCollaborativeUserDelete"
        case .fileColorUpdate:
            localizedKey = "fileDetailsActivityFileColorUpdate"
        case .fileColorDelete:
            localizedKey = "fileDetailsActivityFileColorDelete"
        case .none:
            localizedKey = "fileActivityUnknown"
        }
        detailLabel.text = localizedKey.localized

        timeLabel.text = Constants.formatDate(activity.createdAt, style: .time, relative: true)
    }
}
