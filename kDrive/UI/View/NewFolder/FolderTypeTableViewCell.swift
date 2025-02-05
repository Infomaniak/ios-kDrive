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
import UIKit

class FolderTypeTableViewCell: InsetTableViewCell {
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var chipContainerView: UIView!

    override func prepareForReuse() {
        super.prepareForReuse()
        descriptionLabel.text = nil
        chipContainerView.subviews.forEach { $0.removeFromSuperview() }
    }

    public func setMykSuiteChip() {
        let chipView = MyKSuiteChip.instantiateGreyChip()
        chipView.translatesAutoresizingMaskIntoConstraints = false
        chipContainerView.addSubview(chipView)

        NSLayoutConstraint.activate([
            chipView.leadingAnchor.constraint(equalTo: chipContainerView.leadingAnchor),
            chipView.trailingAnchor.constraint(equalTo: chipContainerView.trailingAnchor),
            chipView.topAnchor.constraint(equalTo: chipContainerView.topAnchor),
            chipView.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor)
        ])
    }
}
