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

import kDriveResources
import UIKit

class EmptyTableView: UIView {
    enum EmptyTableViewType {
        case noNetwork
        case noOffline
        case noTrash
        case emptyFolderSelectFolder
        case emptyFolderWithCreationRights
        case emptyFolder
        case noFavorite
        case noShared
        case noSharedWithMe
        case noSearchResults
        case noActivities
        case noActivitiesSolo
        case noImages
        case noComments
        case noCategories
    }

    @IBOutlet var bottomToButtonConstraint: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var mandatoryTopConstraint: NSLayoutConstraint!
    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var centerConstraint: NSLayoutConstraint!
    @IBOutlet var emptyImageFrameView: UIView!
    @IBOutlet var emptyMessageLabel: UILabel!
    @IBOutlet var emptyDetailsLabel: UILabel!
    @IBOutlet var emptyImageView: UIImageView!
    @IBOutlet var reloadButton: UIButton!
    @IBOutlet var emptyImageFrameViewHeightConstant: NSLayoutConstraint!
    var actionHandler: ((UIButton) -> Void)?

    private func setCenteringEnabled(_ enabled: Bool) {
        centerConstraint.isActive = enabled
        mandatoryTopConstraint.isActive = enabled
        topConstraint.isActive = !enabled
    }

    class func instantiate(
        logo: UIImage,
        message: String,
        details: String = "",
        button: Bool = false,
        backgroundColor: UIColor = KDriveResourcesAsset.backgroundCardViewColor.color
    ) -> EmptyTableView {
        let view = Bundle.main.loadNibNamed("EmptyTableView", owner: nil, options: nil)![0] as! EmptyTableView
        view.emptyImageView.image = logo
        view.emptyMessageLabel.text = message
        view.emptyDetailsLabel.text = details
        view.emptyImageFrameView.backgroundColor = backgroundColor
        view.emptyImageFrameView.cornerRadius = view.emptyImageFrameView.frame.height / 2

        view.bottomToButtonConstraint.isActive = button
        view.bottomConstraint.isActive = !button
        view.reloadButton.isHidden = !button

        return view
    }

    class func instantiate(type: EmptyTableViewType, button: Bool = false, setCenteringEnabled: Bool = true) -> EmptyTableView {
        let view: EmptyTableView
        switch type {
        case .noNetwork:
            view = instantiate(
                logo: KDriveResourcesAsset.offline.image,
                message: KDriveResourcesStrings.Localizable.noFilesDescriptionNoNetwork,
                button: button
            )
        case .noOffline:
            view = instantiate(
                logo: KDriveResourcesAsset.availableOffline.image,
                message: KDriveResourcesStrings.Localizable.offlineFileNoFile,
                details: KDriveResourcesStrings.Localizable.offlineFileNoFileDescription
            )
        case .noTrash:
            view = instantiate(logo: KDriveResourcesAsset.delete.image, message: KDriveResourcesStrings.Localizable.trashNoFile)
        case .emptyFolder, .emptyFolderSelectFolder:
            view = instantiate(
                logo: KDriveResourcesAsset.folderFilled.image,
                message: KDriveResourcesStrings.Localizable.noFilesDescription
            )
        case .emptyFolderWithCreationRights:
            view = instantiate(
                logo: KDriveResourcesAsset.folderFilled.image,
                message: KDriveResourcesStrings.Localizable.noFilesDescriptionWithCreationRights
            )
        case .noFavorite:
            view = instantiate(
                logo: KDriveResourcesAsset.favorite.image,
                message: KDriveResourcesStrings.Localizable.favoritesNoFile
            )
            view.emptyImageView.tintColor = KDriveResourcesAsset.favoriteColor.color
        case .noShared:
            view = instantiate(logo: KDriveResourcesAsset.share.image, message: KDriveResourcesStrings.Localizable.mySharesNoFile)
        case .noSharedWithMe:
            view = instantiate(
                logo: KDriveResourcesAsset.share.image,
                message: KDriveResourcesStrings.Localizable.sharedWithMeNoFile
            )
        case .noSearchResults:
            view = instantiate(logo: KDriveResourcesAsset.search.image, message: KDriveResourcesStrings.Localizable.searchNoFile)
        case .noActivities:
            view = instantiate(
                logo: KDriveResourcesAsset.copy.image,
                message: KDriveResourcesStrings.Localizable.homeNoActivities,
                details: KDriveResourcesStrings.Localizable.homeNoActivitiesDescription
            )
        case .noActivitiesSolo:
            view = instantiate(
                logo: KDriveResourcesAsset.copy.image,
                message: KDriveResourcesStrings.Localizable.homeNoActivities,
                details: KDriveResourcesStrings.Localizable.homeNoActivitiesDescriptionSolo
            )
        case .noImages:
            view = instantiate(
                logo: KDriveResourcesAsset.images.image,
                message: KDriveResourcesStrings.Localizable.homeNoPictures
            )
        case .noComments:
            view = instantiate(
                logo: KDriveResourcesAsset.comment.image,
                message: KDriveResourcesStrings.Localizable.fileDetailsNoComments,
                backgroundColor: KDriveResourcesAsset.backgroundColor.color
            )
        case .noCategories:
            view = instantiate(
                logo: KDriveResourcesAsset.categories.image,
                message: KDriveResourcesStrings.Localizable.manageCategoriesNoCategory
            )
        }

        if !setCenteringEnabled {
            view.setCenteringEnabled(false)
        }
        return view
    }

    @IBAction func reloadButtonClicked(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
