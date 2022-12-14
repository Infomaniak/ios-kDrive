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
        case emptyFolder
        case emptyFolderSelectFolder
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

    @IBOutlet weak var bottomToButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var mandatoryTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var centerConstraint: NSLayoutConstraint!
    @IBOutlet weak var emptyImageFrameView: UIView!
    @IBOutlet weak var emptyMessageLabel: UILabel!
    @IBOutlet weak var emptyDetailsLabel: UILabel!
    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var reloadButton: UIButton!
    @IBOutlet weak var emptyImageFrameViewHeightConstant: NSLayoutConstraint!
    var actionHandler: ((UIButton) -> Void)?

    private func setCenteringEnabled(_ enabled: Bool) {
        self.centerConstraint.isActive = enabled
        self.mandatoryTopConstraint.isActive = enabled
        self.topConstraint.isActive = !enabled
    }

    class func instantiate(logo: UIImage, message: String, details: String = "", button: Bool = false, backgroundColor: UIColor = KDriveResourcesAsset.backgroundCardViewColor.color) -> EmptyTableView {
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
            view = self.instantiate(logo: KDriveResourcesAsset.offline.image, message: KDriveResourcesStrings.Localizable.noFilesDescriptionNoNetwork, button: button)
        case .noOffline:
            view = self.instantiate(logo: KDriveResourcesAsset.availableOffline.image, message: KDriveResourcesStrings.Localizable.offlineFileNoFile, details: KDriveResourcesStrings.Localizable.offlineFileNoFileDescription)
        case .noTrash:
            view = self.instantiate(logo: KDriveResourcesAsset.delete.image, message: KDriveResourcesStrings.Localizable.trashNoFile)
        case .emptyFolder:
            view = self.instantiate(logo: KDriveResourcesAsset.folderFilled.image, message: KDriveResourcesStrings.Localizable.noFilesDescriptionWithCreationRights)
        case .emptyFolderSelectFolder:
            view = self.instantiate(logo: KDriveResourcesAsset.folderFilled.image, message: KDriveResourcesStrings.Localizable.noFilesDescription)
        case .noFavorite:
            view = self.instantiate(logo: KDriveResourcesAsset.favorite.image, message: KDriveResourcesStrings.Localizable.favoritesNoFile)
            view.emptyImageView.tintColor = KDriveResourcesAsset.favoriteColor.color
        case .noShared:
            view = self.instantiate(logo: KDriveResourcesAsset.share.image, message: KDriveResourcesStrings.Localizable.mySharesNoFile)
        case .noSharedWithMe:
            view = self.instantiate(logo: KDriveResourcesAsset.share.image, message: KDriveResourcesStrings.Localizable.sharedWithMeNoFile)
        case .noSearchResults:
            view = self.instantiate(logo: KDriveResourcesAsset.search.image, message: KDriveResourcesStrings.Localizable.searchNoFile)
        case .noActivities:
            view = self.instantiate(logo: KDriveResourcesAsset.copy.image, message: KDriveResourcesStrings.Localizable.homeNoActivities, details: KDriveResourcesStrings.Localizable.homeNoActivitiesDescription)
        case .noActivitiesSolo:
            view = self.instantiate(logo: KDriveResourcesAsset.copy.image, message: KDriveResourcesStrings.Localizable.homeNoActivities, details: KDriveResourcesStrings.Localizable.homeNoActivitiesDescriptionSolo)
        case .noImages:
            view = self.instantiate(logo: KDriveResourcesAsset.images.image, message: KDriveResourcesStrings.Localizable.homeNoPictures)
        case .noComments:
            view = self.instantiate(logo: KDriveResourcesAsset.comment.image, message: KDriveResourcesStrings.Localizable.fileDetailsNoComments, backgroundColor: KDriveResourcesAsset.backgroundColor.color)
        case .noCategories:
            view = self.instantiate(logo: KDriveResourcesAsset.categories.image, message: KDriveResourcesStrings.Localizable.manageCategoriesNoCategory)
        }

        if !setCenteringEnabled {
            view.setCenteringEnabled(false)
        }
        return view
    }

    @IBAction func reloadButtonClicked(_ sender: UIButton) {
        self.actionHandler?(sender)
    }
}
