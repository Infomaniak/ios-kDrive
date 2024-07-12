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
import UIKit

class FloatingPanelSortOptionTableViewCell: InsetTableViewCell {
    @IBOutlet var iconImageView: UIImageView!

    var isHeader = false {
        didSet { setUpView() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        setUpView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        setUpView()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        accessoryImageView.isHidden = !selected
    }

    private func setUpView() {
        accessoryImageView.isHidden = !isSelected
        separator?.isHidden = !isHeader
        iconImageView.isHidden = true
        setAccessibility()
    }

    private func setAccessibility() {
        if isHeader {
            accessibilityTraits = isSelected ? [.selected, .header] : .header
        } else {
            accessibilityTraits = isSelected ? [.selected, .staticText] : .staticText
        }
    }
}
