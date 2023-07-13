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
import UIKit

protocol SearchFilterCellDelegate: AnyObject {
    func removeButtonPressed(_ filter: Filterable)
}

class SearchFilterCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: IKLabel!
    @IBOutlet weak var removeButton: UIButton!

    weak var delegate: SearchFilterCellDelegate?

    private var filter: Filterable!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.layer.cornerRadius = UIConstants.buttonCornerRadius
        contentView.clipsToBounds = true
        removeButton.accessibilityLabel = KDriveResourcesStrings.Localizable.buttonDelete
    }

    func configure(with filter: Filterable) {
        self.filter = filter
        iconImageView.image = filter.icon
        iconImageView.tintColor = filter is ConvertedType ? KDriveResourcesAsset.infomaniakColor.color : KDriveResourcesAsset
            .secondaryTextColor.color
        titleLabel.text = filter.localizedName
        titleLabel.sizeToFit()
    }

    @IBAction func removeButtonPressed(_ sender: UIButton) {
        guard filter != nil else { return }
        delegate?.removeButtonPressed(filter)
    }
}
