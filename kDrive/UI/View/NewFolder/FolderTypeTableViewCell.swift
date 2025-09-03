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
import KSuite
import UIKit

class FolderTypeTableViewCell: InsetTableViewCell {
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var upgradeLabel: UILabel!
    @IBOutlet var chipContainerView: UIView!
    @IBOutlet var lowerConstraint: NSLayoutConstraint!

    override func prepareForReuse() {
        super.prepareForReuse()
        descriptionLabel.text = nil
        upgradeLabel.text = nil
        upgradeLabel.isHidden = true
        lowerConstraint.constant = 0
        chipContainerView.subviews.forEach { $0.removeFromSuperview() }
    }

    override func initWithPositionAndShadow(
        isFirst: Bool = false,
        isLast: Bool = false,
        elevation: Double = 0,
        radius: CGFloat = 6
    ) {
        upgradeLabel.isHidden = true
        lowerConstraint.constant = 0
        super.initWithPositionAndShadow(isFirst: isFirst, isLast: isLast, elevation: elevation, radius: radius)
    }

    func setMykSuiteChip() {
        let chipView = MyKSuiteChip.instantiateGrayChip()
        chipView.translatesAutoresizingMaskIntoConstraints = false
        chipContainerView.addSubview(chipView)

        NSLayoutConstraint.activate([
            chipView.leadingAnchor.constraint(equalTo: chipContainerView.leadingAnchor),
            chipView.trailingAnchor.constraint(equalTo: chipContainerView.trailingAnchor),
            chipView.topAnchor.constraint(equalTo: chipContainerView.topAnchor),
            chipView.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor)
        ])
    }

    func setKSuiteProChip() {
        let chip = KSuiteProChipController()
        guard let chipView = chip.view else {
            return
        }

        chipView.translatesAutoresizingMaskIntoConstraints = false
        chipContainerView.addSubview(chipView)

        NSLayoutConstraint.activate([
            chipView.leadingAnchor.constraint(equalTo: chipContainerView.leadingAnchor),
            chipView.trailingAnchor.constraint(equalTo: chipContainerView.trailingAnchor),
            chipView.topAnchor.constraint(equalTo: chipContainerView.topAnchor),
            chipView.bottomAnchor.constraint(equalTo: chipContainerView.bottomAnchor)
        ])
    }

    func setKSuiteEnterpriseUpgrade(isAdmin: Bool) {
        if isAdmin {
            upgradeLabel.text = KSuiteLocalizable.kSuiteUpgradeDetails
        } else {
            upgradeLabel.text = KSuiteLocalizable.kSuiteUpgradeDetailsContactAdmin
        }
        upgradeLabel.isHidden = false
        lowerConstraint.constant = 20
    }
}
