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

import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

class RightsSelectionTableViewCell: InsetTableViewCell {
    @IBOutlet var rightsIconImageView: UIImageView!
    @IBOutlet var rightsTitleLabel: UILabel!
    @IBOutlet var rightsDetailLabel: UILabel!
    @IBOutlet var bannerView: UIView!
    @IBOutlet var bannerBackgroundView: UIView!
    @IBOutlet var bannerLabel: UILabel!
    @IBOutlet var updateButton: UIButton!

    var isSelectable = true
    var actionHandler: ((UIButton) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        bannerView.isHidden = true
        updateButton.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        bannerView.isHidden = true
        updateButton.isHidden = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        contentInsetView.backgroundColor = KDriveResourcesAsset.backgroundCardViewColor.color
        if isSelectable {
            if selected {
                contentInsetView.borderColor = KDriveResourcesAsset.infomaniakColor.color
                contentInsetView.borderWidth = 2
            } else {
                contentInsetView.borderWidth = 0
            }
        }
    }

    func configureCell(right: Right, type: RightsSelectionType, disable: Bool, file: File) {
        rightsTitleLabel.text = right.title
        rightsDetailLabel.text = file.isDirectory ? right.folderDescription : file.isOfficeFile ? right
            .documentDescription : right.fileDescription
        rightsIconImageView.image = right.icon

        if disable {
            disableCell()
            if type == .shareLinkSettings {
                bannerView.isHidden = true
                updateButton.isHidden = false
            }
        } else {
            enableCell()
        }

        if right.key == UserPermission.delete.rawValue {
            rightsIconImageView.tintColor = KDriveResourcesAsset.binColor.color
        }
    }

    func disableCell() {
        rightsTitleLabel.alpha = 0.5
        rightsDetailLabel.alpha = 0.5
        rightsIconImageView.alpha = 0.5
        bannerView.isHidden = false
        isSelectable = false
        let borderColor = contentInsetView.borderColor
        contentInsetView.layer.borderColor = borderColor!.withAlphaComponent(0.5).cgColor
    }

    func enableCell() {
        rightsTitleLabel.alpha = 1
        rightsDetailLabel.alpha = 1
        rightsIconImageView.alpha = 1
        bannerView.isHidden = true
        isSelectable = true
    }

    @IBAction func updateButtonPressed(_ sender: UIButton) {
        actionHandler?(sender)
    }
}
