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

class EmptyTableView: UIView {

    enum EmptyTableViewType {
        case noNetwork
        case noOffline
        case noTrash
        case emptyFolder
        case noFavorite
        case noShared
        case noSharedWithMe
        case noSearchResults
        case noActivities
        case noActivitiesSolo
        case noImages
        case noComments
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
    var actionHandler: ((UIButton) -> Void)?

    private func setCenteringEnabled(_ enabled: Bool) {
        centerConstraint.isActive = enabled
        mandatoryTopConstraint.isActive = enabled
        topConstraint.isActive = !enabled
    }

    class func instantiate(logo: UIImage, message: String, details: String = "", button: Bool = false, backgroundColor: UIColor =  KDriveAsset.backgroundCardViewColor.color) -> EmptyTableView {
        let view = Bundle.main.loadNibNamed("EmptyTableView", owner: nil, options: nil)![0] as! EmptyTableView
        view.emptyImageView.image = logo
        view.emptyMessageLabel.text = message
        view.emptyDetailsLabel.text = details
        view.emptyImageFrameView.backgroundColor = backgroundColor

        view.bottomToButtonConstraint.isActive = button
        view.bottomConstraint.isActive = !button
        view.reloadButton.isHidden = !button

        return view
    }

    class func instantiate(type: EmptyTableViewType, button: Bool = false) -> EmptyTableView {
        switch type {
        case .noNetwork:
            let view = self.instantiate(logo: KDriveAsset.offline.image, message: KDriveStrings.Localizable.noFilesDescriptionNoNetwork, button: button)
            return view
        case .noOffline:
            let view = self.instantiate(logo: KDriveAsset.availableOffline.image, message: KDriveStrings.Localizable.offlineFileNoFile, details: KDriveStrings.Localizable.offlineFileNoFileDescription)
            return view
        case .noTrash:
            let view = self.instantiate(logo: KDriveAsset.delete.image, message: KDriveStrings.Localizable.trashNoFile)
            return view
        case .emptyFolder:
            let view = self.instantiate(logo: KDriveAsset.folderFilled.image, message: KDriveStrings.Localizable.noFilesDescription)
            return view
        case .noFavorite:
            let view = self.instantiate(logo: KDriveAsset.favorite.image, message: KDriveStrings.Localizable.favoritesNoFile)
            view.emptyImageView.tintColor = KDriveAsset.favoriteColor.color
            return view
        case .noShared:
            let view = self.instantiate(logo: KDriveAsset.share.image, message: KDriveStrings.Localizable.mySharesNoFile)
            return view
        case .noSharedWithMe:
            let view = self.instantiate(logo: KDriveAsset.share.image, message: KDriveStrings.Localizable.sharedWithMeNoFile)
            return view
        case .noSearchResults:
            let view = self.instantiate(logo: KDriveAsset.search.image, message: KDriveStrings.Localizable.searchNoFile)
            return view
        case .noActivities:
            let view = self.instantiate(logo: KDriveAsset.copy.image, message: KDriveStrings.Localizable.homeNoActivities, details: KDriveStrings.Localizable.homeNoActivitiesDescription)
            view.setCenteringEnabled(false)
            return view
        case .noActivitiesSolo:
            let view = self.instantiate(logo: KDriveAsset.copy.image, message: KDriveStrings.Localizable.homeNoActivities, details: KDriveStrings.Localizable.homeNoActivitiesDescriptionSolo)
            view.setCenteringEnabled(false)
            return view
        case .noImages:
            let view = self.instantiate(logo: KDriveAsset.images.image, message: KDriveStrings.Localizable.homeNoPictures)
            view.setCenteringEnabled(false)
            return view
        case .noComments:
            let view = self.instantiate(logo: KDriveAsset.comment.image, message: KDriveStrings.Localizable.fileDetailsNoComments, backgroundColor: KDriveAsset.backgroundColor.color)
            view.setCenteringEnabled(false)
            return view
        }
    }

    @IBAction func reloadButtonClicked(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
